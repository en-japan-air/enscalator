# -*- encoding : utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'semantic'

module Enscalator

  module Plugins

    # Elasticsearch related configuration
    module Elasticsearch

      class << self

        # Supported storage types in AWS
        STORAGE=[:'ebs', :'instance-store']

        # Supported Elasticsearch image architectures
        ARCH=[:amd64, :i386]

        # Get ami region/virtualization type mapping
        #
        # @param storage [Symbol] image root storage
        # @param arch [Symbol] image architecture type
        # @return [Hash] mapping
        def get_mapping(storage: :ebs, arch: :amd64)
          raise ArgumentError, "storage can only be one of #{STORAGE.to_s}" unless STORAGE.include? storage
          raise ArgumentError, "arch can only be one of #{ARCH.to_s}" unless ARCH.include? arch
          fetch_mapping(storage, arch)
        end

        # Get ami release version string
        #
        # @param storage [Symbol] image root storage
        # @param arch [Symbol] image architecture type
        # @return [Hash] mapping
        def get_release_version(storage: :ebs, arch: :amd64)
          raise ArgumentError, "storage can only be one of #{STORAGE.to_s}" unless STORAGE.include? storage
          raise ArgumentError, "arch can only be one of #{ARCH.to_s}" unless ARCH.include? arch
          fetch_versions
            .select(&->(r) { r.root_storage == storage && r.arch == arch })
            .map(&->(v) { v.version.to_s }).uniq.first
            .gsub(/[-][\w\d]/, '')
        end

        private

        # Structure to hold parsed record
        Struct.new('Elasicsearch', :name, :version, :baseos, :root_storage, :arch, :region, :ami, :virtualization)

        # Always fetches the most recent version
        #
        # @param storage [Symbol] image root storage
        # @param arch [Symbol] image architecture type
        # @return [Hash] mapping
        def fetch_mapping(storage, arch)
          versions = fetch_versions
          versions.select(&->(r) { r.root_storage == storage && r.arch == arch })
            .group_by(&:region)
            .map(&->(k, v) {
                   [
                     k,
                     v.map(&->(i) { [i.virtualization, i.ami] }).to_h
                   ]
                 }
            )
            .to_h
            .with_indifferent_access
        end

        # Make request to Bitnami Elasticsearch release pages, parse response and make
        #
        # @return [Array] list of all versions across all AWS regions
        def fetch_versions
          html = Nokogiri::HTML(open('https://bitnami.com/stack/elasticsearch/cloud/amazon'))
          raw_entries = html.xpath('//td[@class="instance_id"]')
          entries = raw_entries.xpath('a')
          raw_entries.xpath('strong/a').each { |sa| entries << sa }
          raw_versions = entries.map { |i| [
            i.xpath('@href').first.value.split('/').last,
            i.children.first.text
          ] }.to_h
          parse_versions(raw_versions)
        end

        # Parse list of raw strings
        #
        # @param entries [Array] list of strings
        # @return [Array]
        def parse_versions(entries)
          entries.map do |rw, ami|
            str, region = rw.split('?').map { |s| s.start_with?('region') ? s.split('=').last : s }
            version_str = fix_entry(str).split('-')
            name, version, baseos = version_str
            Struct::Elasicsearch.new(name,
                                     Semantic::Version.new(version.gsub('=', '-')),
                                     baseos,
                                     version_str.include?('ebs') ? :'ebs' : :'instance-store',
                                     version_str.include?('x64') ? :amd64 : :i386,
                                     region,
                                     ami,
                                     version_str.include?('hvm') ? :hvm : :pv)
          end
        end

        # Fix elasticsearch version string to have predictable format
        #
        # @param str [String] raw version string
        # @return [String] reformatted version string
        def fix_entry(str)
          pattern = '[-](?:[\w\d]+){1,3}[-]ami'
          token = Regexp.new(pattern.gsub('?:', '')).match(str)[1] rescue nil
          str.gsub(Regexp.new(pattern), ['=', token, '-'].join)
        end

      end # class << self

      # Create new elasticsearch instance
      #
      # @param db_name [String] database name
      # @param allocated_storage [Integer] size of instance primary storage
      # @param instance_class [String] instance class (type)
      def elasticsearch_init(db_name,
                             allocated_storage: 5,
                             instance_class: 't2.medium',
                             properties: {})

        mapping 'AWSElasticsearchAMI', Elasticsearch.get_mapping

        parameter_keyname "Elasticsearch#{db_name}"

        parameter_allocated_storage "Elasticsearch#{db_name}",
                                    default: allocated_storage,
                                    min: 5,
                                    max: 1024

        parameter_instance_class "Elasticsearch#{db_name}",
                                 default: instance_class,
                                 allowed_values: %w(t2.micro t2.small t2.medium m3.medium
                                                 m3.large m3.xlarge m3.2xlarge)

        properties[:KeyName] = ref("Elasticsearch#{db_name}KeyName")
        properties[:InstanceType] = ref("Elasticsearch#{db_name}InstanceClass")

        version_tag = {
          Key: 'Version',
          Value: Elasticsearch.get_release_version
        }

        cluster_name_tag = {
          Key: 'ClusterName',
          Value: db_name
        }

        plugin_tags = [version_tag, cluster_name_tag]

        # Set instance tags
        if properties.has_key?(:Tags) && !properties[:Tags].empty?
          properties[:Tags].concat(plugin_tags)
        else
          properties[:Tags] = plugin_tags
        end

        # Configure instance using user-data
        if !properties.has_key?(:UserData) || !properties[:UserData].empty?
          properties[:UserData] = Base64.encode64(read_user_data('elasticsearch'))
        end

        # Assign IAM role to instance
        properties[:IamInstanceProfile] = iam_instance_profile_with_full_access(db_name, *%w(ec2 s3))

        instance_vpc("Elasticsearch#{db_name}",
                     find_in_map('AWSElasticsearchAMI', ref('AWS::Region'), :hvm),
                     ref_application_subnet_a,
                     [ref_private_security_group, ref_resource_security_group],
                     dependsOn: [],
                     properties: properties
        )
      end
    end # module Elasticsearch
  end # module Plugins
end # module Enscalator
