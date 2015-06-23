# -*- encoding : utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'semantic'

module Enscalator

  module Plugins

    # Elasticsearch related configuration
    module Elasticsearch
      include Enscalator::Helpers

      # Retrieves mapping for Elasticsearch Bitnami stack
      class << self

        # Supported storage types in AWS
        STORAGE=[:'ebs', :'instance-store']

        # Supported Elasticsearch image architectures
        ARCH=[:amd64, :i386]

        # Get ami region/virtualization type mapping
        #
        # @param [Symbol] storage image root storage
        # @param [Symbol] arch image architecture type
        # @return [Hash] mapping
        def get_mapping(storage: :ebs, arch: :amd64)
          raise ArgumentError, "storage can only be one of #{STORAGE.to_s}" unless STORAGE.include? storage
          raise ArgumentError, "arch can only be one of #{ARCH.to_s}" unless ARCH.include? arch
          fetch_mapping(storage, arch)
        end

        # Get ami release version string
        #
        # @param [Symbol] storage image root storage
        # @param [Symbol] arch image architecture type
        # @return [Hash] mapping
        def get_release_version(storage: :ebs, arch: :amd64)
          raise ArgumentError, "storage can only be one of #{STORAGE.to_s}" unless STORAGE.include? storage
          raise ArgumentError, "arch can only be one of #{ARCH.to_s}" unless ARCH.include? arch
          fetch_versions
            .select { |r| r.root_storage == storage && r.arch == arch }
            .map { |v| v.version.to_s }.uniq.first
            .gsub(/[-][\w\d]/, '')
        end

        private

        # Structure to hold parsed record
        Struct.new('ElasticSearch', :name, :version, :baseos, :root_storage, :arch, :region, :ami, :virtualization)

        # Always fetches the most recent version
        #
        # @param [Symbol] storage image root storage
        # @param [Symbol] arch image architecture type
        # @return [Hash] mapping
        def fetch_mapping(storage, arch)
          versions = fetch_versions
          versions.select { |r| r.root_storage == storage && r.arch == arch }
            .group_by(&:region)
            .map { |k, v| [k,
                           v.map { |i| [i.virtualization, i.ami] }.to_h] }.to_h
            .with_indifferent_access
        end

        # Make request to Bitnami Elasticsearch release pages, parse response and make list of versions
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
            Struct::ElasticSearch.new(name,
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
        # @param [String] str raw version string
        # @return [String] reformatted version string
        def fix_entry(str)
          pattern = '[-](?:[\w\d]+){1,3}[-]ami'
          token = Regexp.new(pattern.gsub('?:', '')).match(str)[1] rescue nil
          str.gsub(Regexp.new(pattern), ['=', token, '-'].join)
        end

      end # class << self

      # Create new elasticsearch instance
      #
      # @param [String] storage_name storage name
      # @param [Integer] allocated_storage size of instance primary storage
      # @param [String] instance_type instance type
      # @param [Hash] properties additional properties
      # @param [String] zone_name route53 zone name
      # @param [Integer] ttl time to live value
      def elasticsearch_init(storage_name,
                             allocated_storage: 5,
                             instance_type: 't2.medium',
                             properties: {},
                             zone_name: nil,
                             ttl: 300)

        @key_name = "Elasticsearch#{storage_name}".underscore

        pre_run do
          create_ssh_key @key_name,
                         region,
                         force_create: false
        end

        mapping 'AWSElasticsearchAMI', Elasticsearch.get_mapping

        parameter_allocated_storage "Elasticsearch#{storage_name}",
                                    default: allocated_storage,
                                    min: 5,
                                    max: 1024

        parameter_instance_type "Elasticsearch#{storage_name}", type: instance_type

        properties[:KeyName] = @key_name
        properties[:InstanceType] = ref("Elasticsearch#{storage_name}InstanceClass")

        version_tag = {
          Key: 'Version',
          Value: Elasticsearch.get_release_version
        }

        cluster_name_tag = {
          Key: 'ClusterName',
          Value: storage_name.downcase
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
        properties[:IamInstanceProfile] = iam_instance_profile_with_full_access(storage_name, *%w(ec2 s3))

        instance_vpc "Elasticsearch#{storage_name}",
                     find_in_map('AWSElasticsearchAMI', ref('AWS::Region'), :hvm),
                     ref_application_subnet_a,
                     [ref_private_security_group, ref_resource_security_group],
                     dependsOn: [],
                     properties: properties

        post_run do
          cfn = cfn_resource(cfn_client(region))

          # wait for the stack to be created
          stack = wait_stack(cfn, stack_name)

          # get elasticsearch instance IP address
          es_ip_addr = get_resource(stack, "Elasticsearch#{storage_name}PrivateIpAddress")

          # create a DNS record in route53
          upsert_dns_record zone_name: zone_name,
                            record_name: "elasticsearch.#{storage_name.downcase}.#{zone_name}",
                            type: 'A',
                            values: [es_ip_addr],
                            ttl: ttl,
                            region: region
        end
      end
    end # module Elasticsearch
  end # module Plugins
end # module Enscalator
