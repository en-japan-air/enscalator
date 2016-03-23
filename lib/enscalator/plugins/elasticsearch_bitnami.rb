module Enscalator
  module Plugins
    # Elasticsearch related configuration
    module ElasticsearchBitnami
      # Retrieves mapping for Elasticsearch Bitnami stack
      class << self
        # Supported storage types in AWS
        STORAGE = [:ebs, :'instance-store']

        # Supported Elasticsearch image architectures
        ARCH = [:amd64, :i386]

        # Get ami region/virtualization type mapping
        #
        # @param [Symbol] storage image root storage
        # @param [Symbol] arch image architecture type
        # @return [Hash] mapping
        def get_mapping(storage: :ebs, arch: :amd64)
          fail ArgumentError, "storage can only be one of #{STORAGE}" unless STORAGE.include? storage
          fail ArgumentError, "arch can only be one of #{ARCH}" unless ARCH.include? arch
          fetch_mapping(storage, arch)
        end

        # Get ami release version string
        #
        # @param [Symbol] storage image root storage
        # @param [Symbol] arch image architecture type
        # @return [Hash] mapping
        def get_release_version(storage: :ebs, arch: :amd64)
          fail ArgumentError, "storage can only be one of #{STORAGE}" unless STORAGE.include? storage
          fail ArgumentError, "arch can only be one of #{ARCH}" unless ARCH.include? arch
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
            .map { |k, v| [k, v.map { |i| [i.virtualization, i.ami] }.to_h] }.to_h
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
          raw_versions = entries.map do |i|
            [
              i.xpath('@href').first.value.split('/').last,
              i.children.first.text
            ]
          end.to_h
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
                                      Semantic::Version.new(version.tr('=', '-')),
                                      baseos,
                                      version_str.include?('ebs') ? :ebs : :'instance-store',
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
          token = begin
            Regexp.new(pattern.gsub('?:', '')).match(str)[1]
          rescue
            nil
          end
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
      def elasticsearch_init(storage_name,
                             allocated_storage: 5,
                             instance_type: 't2.medium',
                             properties: {},
                             zone_name: nil)

        @es_key_name = gen_ssh_key_name("Elasticsearch#{storage_name}", region, stack_name)
        pre_run { create_ssh_key(@es_key_name, region, force_create: false) }

        mapping 'AWSElasticsearchAMI', ElasticsearchBitnami.get_mapping

        parameter_allocated_storage "Elasticsearch#{storage_name}",
                                    default: allocated_storage,
                                    min: 5,
                                    max: 1024

        parameter_ec2_instance_type "Elasticsearch#{storage_name}", type: instance_type

        properties[:KeyName] = @es_key_name
        properties[:InstanceType] = ref("Elasticsearch#{storage_name}InstanceType")

        version_tag = {
          Key: 'Version',
          Value: ElasticsearchBitnami.get_release_version
        }

        cluster_name_tag = {
          Key: 'ClusterName',
          Value: storage_name.downcase
        }

        plugin_tags = [version_tag, cluster_name_tag]

        # Set instance tags
        if properties.key?(:Tags) && !properties[:Tags].empty?
          properties[:Tags].concat(plugin_tags)
        else
          properties[:Tags] = plugin_tags
        end

        # Configure instance using user-data
        if !properties.key?(:UserData) || !properties[:UserData].empty?
          properties[:UserData] = Base64.encode64(read_user_data('elasticsearch'))
        end

        # Assign IAM role to instance
        properties[:IamInstanceProfile] = iam_instance_profile_with_full_access(storage_name, *%w(ec2 s3))

        storage_resource_name = "Elasticsearch#{storage_name}"
        instance_vpc storage_resource_name,
                     find_in_map('AWSElasticsearchAMI', ref('AWS::Region'), :hvm),
                     ref_application_subnets.first,
                     [ref_private_security_group, ref_resource_security_group],
                     dependsOn: [],
                     properties: properties

        # create a DNS record in route53 for instance private ip
        record_name = %W(#{storage_name.downcase.dasherize} #{region} #{zone_name}).join('.')
        create_single_dns_record("#{storage_name}PrivateZone",
                                 stack_name,
                                 zone_name,
                                 record_name,
                                 resource_records: [get_att(storage_resource_name, 'PrivateIp')])
      end
    end # module ElasticsearchBitnami
  end # module Plugins
end # module Enscalator
