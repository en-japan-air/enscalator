module Enscalator
  module Plugins
    # Debian appliance
    module Debian
      class << self
        # Supported storage types in AWS
        STORAGE = [:ebs, :'instance-store']

        # Supported Debian image architectures
        ARCH = [:x86_64, :i386]

        # Supported Debian releases
        RELEASE = { jessie: '8', wheezy: '7' }

        # Structure to hold parsed record
        Struct.new('Debian', :region, :ami, :virtualization, :arch, :root_storage)

        # @param [Symbol, String] release a codename or version number
        # @param [Symbol] storage storage kind
        # @param [Symbol] arch architecture
        # @raise [ArgumentError] if release is nil, empty or not one of supported values
        # @raise [ArgumentError] if storage is nil, empty or not one of supported values
        # @raise [ArgumentError] if arch is nil, empty or not one of supported values
        # @return [Hash] mapping for Debian amis
        def get_mapping(release: :jessie, storage: :ebs, arch: :x86_64)
          fail ArgumentError, 'release can be either codename or version' unless RELEASE.to_a.flatten.include? release
          fail ArgumentError, "storage can only be one of #{STORAGE}" unless STORAGE.include? storage
          fail ArgumentError, "arch can only be one of #{ARCH}" unless ARCH.include? arch
          version = RELEASE.keys.include?(release) ? release : RELEASE.invert[release]
          url = "https://wiki.debian.org/Cloud/AmazonEC2Image/#{version.capitalize}?action=raw"
          body = open(url) { |f| f.read }
          parse_raw_entries(body.split("\r\n").select { |b| b.starts_with?('||') })
            .select { |i| i.ami =~ /ami[-][a-z0-9]{8}/ }
            .select { |r| r.root_storage == storage.to_s && r.arch == arch.to_s }
            .group_by(&:region)
            .map { |k, v| [k, v.map { |i| [i.virtualization, i.ami] }.to_h] }
            .to_h
            .with_indifferent_access
        end

        private

        # Parse raw entries and convert them to meaningful structs
        #
        # @param [Array] items in its raw form
        def parse_raw_entries(items)
          header, *entries = items.map do |item|
            if (item.include?('Region'))..(item.include?('paravirtual'))
              item.downcase.split('||').map(&:strip).map { |i| i.delete("'") }.reject(&:empty?)
            end
          end.compact
          amis = entries.select { |e| e.first =~ /[a-z]{2}-/ }.flat_map do |entry|
            region, *images = entry
            images.map.with_index(1).map do |ami, i|
              [region, ami, header[i].nil? ? '' : header[i].split].flatten
            end
          end

          amis.map { |a| Struct::Debian.new(*a) }
        end
      end
      # Create new Debian instance
      #
      # @param [String] storage storage kind (usually ebs or ephemeral)
      # @param [String] arch architecture (amd64 or i386)
      def debian_init(storage: :ebs, arch: :x86_64)
        mapping 'AWSDebianAMI', Debian.get_mapping(storage: storage, arch: arch)
      end
    end # class Debian
  end # module Plugins
end # module Enscalator
