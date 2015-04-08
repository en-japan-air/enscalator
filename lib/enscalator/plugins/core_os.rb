# encoding: UTF-8

require 'open-uri'
require 'nokogiri'
require 'semantic'

module Enscalator

  # Namespace for enscalator plugins
  module Plugins

    # CoreOS appliance
    module CoreOS

      class << self

        # CoreOS Release channels
        # @see https://coreos.com/releases
        CHANNELS=[:stable, :beta, :alpha]

        # Get CoreOS mapping for specific version from specific channel
        #
        # @param channel [Symbol] channel identifier
        # @param tag [String] specific version release tag
        # @return [Hash] CoreOS mapping for specific version and channel
        def get_channel_version(channel: :stable, tag: nil)
          raise ArgumentError, "channel can only be one of #{CHANNELS.to_s}" unless CHANNELS.include? channel
          base_url = "http://#{channel.to_s}.release.core-os.net/amd64-usr"
          fetch_mapping(base_url, tag)
        end

        # Get CoreOS mapping for specific version regardless of its release channel (stable, beta or alpha)
        #
        # @param tag [String] version tag
        # @return [Hash] CoreOS mapping for specific version
        #  (if tag is not given, returns most latest version number)
        def get_specific_version(tag: nil)
          base_url = 'http://storage.core-os.net/coreos/amd64-usr'
          fetch_mapping(base_url, tag)
        end

        private

        # Fetch CoreOS region/virtualization/ami mapping
        #
        # @param base_url [String] url excluding version number and mapping file
        # @param tag [String] specific version release tag
        # @return [Hash] CoreOS mapping
        def fetch_mapping(base_url, tag)
          raise ArgumentError, 'url cannot be empty' if base_url && base_url.empty?
          versions = fetch_versions(base_url)
          version = if tag && !tag.empty?
                      versions.select { |v| v == Semantic::Version.new(tag) }.first.to_s
                    else
                      versions.sort.last.to_s
                    end

          images = open([base_url, version, 'coreos_production_ami_all.json'].join('/')) { |f| f.read } rescue nil
          json = JSON.parse(images) if images
          parse_raw_mapping(json)
        end

        # Make request to CoreOS release pages, parse response and make a list of versions
        #
        # @param url [String] url to page with CoreOS versions
        # @return [Array] list of Semantic::Version
        def fetch_versions(url)
          html = Nokogiri::HTML(open(url))
          raw_versions = html.xpath('/html/body/a').map { |a| a.children.first.text.chomp('/') }
          raw_versions.select { |rw| rw =~ /^[0-9]/ }.map { |rw| Semantic::Version.new(rw) }
        end

        # Parse and reformat CoreOS default mapping
        #
        # @param coreos_mapping [Array] list of region to virtualization kind mappings
        # @return [Hash] mapping, that can be referred to with find_in_map
        def parse_raw_mapping(coreos_mapping)
          if coreos_mapping
            amis = coreos_mapping.empty? ? [] : coreos_mapping['amis']
            Hash[
              amis.map { |a| [a['name'], {:pv => a['pv'], :hvm => a['hvm']}] }
            ].with_indifferent_access
          end
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
