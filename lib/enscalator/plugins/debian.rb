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
          begin
            version = RELEASE.keys.include?(release) ? release : RELEASE.invert[release]
            url = "https://wiki.debian.org/Cloud/AmazonEC2Image/#{version.to_s.capitalize}?action=raw"
            body = open(url) { |f| f.read }
            parse_raw_entries(body.split("\r\n").select { |b| b.starts_with?('||') })
              .select { |r| r.root_storage == storage.to_s && r.arch == arch.to_s }
              .group_by(&:region)
              .map { |k, v| [k, v.map { |i| [i.virtualization, i.ami] }.to_h] }
              .to_h
              .with_indifferent_access
          end
        end

        private

        # Parse raw entries and convert them to structs
        #
        # @param [Array] items in its raw form
        def parse_raw_entries(items)
          head, *amis = items.map do |item|
            item.sub(/^[||]{2}[ ]/, '')
              .sub(/[ ][||]{2}$/, '')
              .gsub(/([ ]*(:?[|]{2})[ ]*)/, '||')
              .gsub(/[']/, '').downcase.split('||')
          end
          kinds = Hash[head.reject { |k| k == 'region' }.map.with_index.to_a]
          pairs = amis.map { |row| head, *tail = row; tail.map { |r| [head, r].join(' ') } }
          kinds.keys.map { |k| Hash[k, pairs.dup.map { |a| a[kinds[k]] }] }
            .map { |rw| rw.invert.map { |k, v| k.dup.map { |k| [k, v].join(' ') } } }.flatten
            .map { |l| Struct::Debian.new(*l.split(' ')) }
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