module Enscalator
  module Plugins
    # CoreOS appliance
    module CoreOS
      class << self
        # CoreOS Release channels
        # @see https://coreos.com/releases
        CHANNELS = [:alpha, :beta, :stable].freeze

        # Get CoreOS mapping for specific version from specific channel (stable, beta or alpha)
        #
        # @param [Symbol] channel channel identifier
        # @param [String] tag specific version release tag
        # @return [Hash] CoreOS mapping for specific version and channel
        #  (if version tag is not given, returns the most latest version number)
        def get_channel_version(channel: :stable, tag: nil)
          fail ArgumentError, "channel can only be one of #{CHANNELS}" unless CHANNELS.include? channel
          base_url = "http://#{channel}.release.core-os.net/amd64-usr"
          fetch_mapping(base_url, tag)
        end

        # Get CoreOS mapping for specific version regardless of its release channel
        #
        # @param [String] tag version tag
        # @return [Hash] CoreOS mapping for specific version
        #  (if version tag is not given, returns the most latest version number)
        def get_specific_version(tag: nil)
          urls = CHANNELS.map { |c| "http://#{c}.release.core-os.net/amd64-usr" }
          mapping = nil
          urls.each do |u|
            mapping ||= fetch_mapping(u, tag)
          end
          mapping
        end

        private

        # Fetch CoreOS region/virtualization/ami mapping
        #
        # @param [String] base_url url excluding version number and mapping file
        # @param [String] tag specific version release tag
        # @return [Hash] CoreOS mapping
        def fetch_mapping(base_url, tag)
          fail ArgumentError, 'url cannot be empty or nil' if base_url.blank?
          versions = fetch_versions(base_url)
          version = if tag && !tag.empty?
                      versions.find { |v| v == Semantic::Version.new(tag) }.to_s
                    else
                      versions.sort.last.to_s
                    end

          images = begin
            open([base_url, version, 'coreos_production_ami_all.json'].join('/')) { |f| f.read }
          rescue RuntimeError
            nil
          end

          json = JSON.parse(images) if images
          parse_raw_mapping(json)
        end

        # Make request to CoreOS release pages, parse response and make a list of versions
        #
        # @param [String] url of web page with CoreOS versions
        # @return [Array] list of Semantic::Version
        def fetch_versions(url)
          html = Nokogiri::HTML(open(url))
          raw_versions = html.xpath('/html/body/a').map { |a| a.children.first.text.chomp('/') }
          raw_versions.select { |rw| rw =~ /^[0-9]/ }.map { |rw| Semantic::Version.new(rw) }
        end

        # Parse and reformat CoreOS default mapping
        #
        # @param [Array] coreos_mapping list of region to virtualization kind mappings
        # @return [Hash] mapping, that can be referred to with find_in_map
        def parse_raw_mapping(coreos_mapping)
          return {} unless coreos_mapping
          amis = coreos_mapping.empty? ? [] : coreos_mapping['amis']
          Hash[
            amis.map { |a| [a['name'], { pv: a['pv'], hvm: a['hvm'] }] }
          ].with_indifferent_access
        end
      end # class << self

      # Initialize CoreOS related configurations
      #
      def core_os_init
        mapping 'AWSCoreOSAMI', CoreOS.get_channel_version(channel: :stable)
      end
    end # module CoreOS
  end # module Plugins
end # module Enscalator
