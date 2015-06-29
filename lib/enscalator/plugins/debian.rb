# -*- encoding : utf-8 -*-

module Enscalator

  module Plugins

    # Debian appliance
    module Debian

      class << self

        # Supported storage types in AWS
        STORAGE=[:'ebs', :'instance-store']

        # Supported Debian image architectures
        ARCH=[:x86_64, :i386]

        # Supported Debian releases
        RELEASE={
          :jessie => '8',
          :wheezy => '7'
        }

        # Structure to hold parsed record
        Struct.new('Debian', :region, :ami, :virtualization, :arch, :root_storage)

        # @param [Symbol, String] release a codename or version number
        # @param [Symbol] storage storage kind
        # @param [Symbol] arch architecture
        # @raise [ArgumentError] if release is nil, empty or not one of supported values
        # @raise [ArgumentError] if storage is nil, empty or not one of supported values
        # @raise [ArgumentError] if arch is nil, empty or not one of supported values
        # @return [Hash] mapping for Debian amis
        def get_mapping(release: :jessie, storage: :'ebs', arch: :x86_64)
          raise ArgumentError, 'release can be either codename or version' unless RELEASE.to_a.flatten.include? release
          raise ArgumentError, "storage can only be one of #{STORAGE.to_s}" unless STORAGE.include? storage
          raise ArgumentError, "arch can only be one of #{ARCH.to_s}" unless ARCH.include? arch
          version = RELEASE.keys.include?(release) ? release : RELEASE.invert[release]
          url = "https://wiki.debian.org/Cloud/AmazonEC2Image/#{version.capitalize}?action=raw"
          body = open(url) { |f| f.read }
          parse_raw_entries(body.split("\r\n").select { |b| b.starts_with?('||') })
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
            item.downcase.split('||').map(&:strip).map { |i| i.gsub(/[']/, '') }.reject(&:empty?)
          end

          amis = entries.map { |entry|
            region, *images = entry
            images.map.with_index(1).map { |ami, i| [region, ami, header[i].split].flatten }
          }.flatten(1)

          amis.map { |a| Struct::Debian.new(*a) }
            .reject { |a| a.region == 'cn-north-1' || a.region == 'us-gov-west-1' } # TODO: excluded for now
        end

      end

      # Create new Debian instance
      #
      # @param [String] storage storage kind (usually ebs or ephemeral)
      # @param [String] arch architecture (amd64 or i386)
      def debian_init(storage: :'ebs',
                      arch: :x86_64)
        mapping 'AWSDebianAMI', Debian.get_mapping(storage: storage, arch: arch)
      end

    end # class Debian
  end # module Plugins
end # module Enscalator