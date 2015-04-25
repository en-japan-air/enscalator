# -*- encoding : utf-8 -*-

require 'open-uri'
require 'nokogiri'

module Enscalator

  module Plugins

    # Elasticsearch related configuration
    module Elasticsearch

      class << self

        private

        # Always fetches the most recent version
        def fetch_mapping
          versions = fetch_versions('https://bitnami.com/stack/elasticsearch/cloud/amazon')
          versions
        end

        # Make request to Bitnami Elasticsearch release pages, parse response and make
        #
        # @param url [String] url to page with Elasticsearch versions
        # @return [Array] list
        def fetch_versions(url)
          html = Nokogiri::HTML(open(url))
          raw_entries = html.xpath('//td[@class="instance_id"]')
          images = raw_entries.xpath('a')
          raw_entries.xpath('strong/a').each { |sa| images << sa }
          versions = images.map { |r| [r.xpath('@href').first.value.split('/').last, r.children.first.text] }.to_h
          versions
        end

      end

      # Create new elasticsearch instance
      #
      # @param db_name [String] database name
      # @param allocated_storage [Integer] size of instance primary storage
      # @param instance_class [String] instance class (type)
      def elasticsearch_init(db_name,
                             allocated_storage: 5,
                             instance_class: 't2.medium',
                             properties: {})

        # static mapping for elasticsearch 1.4.4
        mapping 'AWSElasticsearchAMI64Ebs',
                {
                  :'us-east-1' => {:hvm => 'ami-36a7f45e', :pv => 'ami-c8a7f4a0'},
                  :'us-west-1' => {:hvm => 'ami-33ca2f77', :pv => 'ami-3dca2f79'},
                  :'us-west-2' => {:hvm => 'ami-9d7657ad', :pv => 'ami-eb7657db'},
                  :'eu-west-1' => {:hvm => 'ami-6948df1e', :pv => 'ami-2d48df5a'},
                  :'eu-central-1' => {:hvm => 'ami-d41f2dc9', :pv => 'ami-d01f2dcd'},
                  :'ap-southeast-1' => {:hvm => 'ami-a88abefa', :pv => 'ami-548bbf06'},
                  :'ap-northeast-1' => {:hvm => 'ami-f938daf9', :pv => 'ami-f538daf5'},
                  :'ap-southeast-2' => {:hvm => 'ami-b5abdd8f', :pv => 'ami-ababdd91'},
                  :'sa-east-1' => {:hvm => 'ami-d12c92cc', :pv => 'ami-d32c92ce'}
                }

        parameter_keyname "Elasticsearch#{db_name}"

        parameter_allocated_storage "Elasticsearch#{db_name}",
                                    default: allocated_storage,
                                    min: 5,
                                    max: 1024

        parameter_instance_class "Elasticsearch#{db_name}",
                                 default: instance_class,
                                 allowed_values: %w(t2.micro t2.small t2.medium m3.medium m3.large m3.xlarge m3.2xlarge)

        properties[:KeyName] = ref("Elasticsearch#{db_name}KeyName")
        properties[:InstanceType] = ref("Elasticsearch#{db_name}InstanceClass")

        instance_vpc("Elasticsearch#{db_name}",
                     # find_in_map('AWSElasticsearchAMI', ref('AWS::Region'), 'amd64'),
                     find_in_map('AWSElasticsearchAMI64Ebs', ref('AWS::Region'), 'hvm'),
                     ref_resource_subnet_a,
                     [ref_private_security_group, ref_resource_security_group],
                     dependsOn: [],
                     properties: properties
        )
      end
    end # module Elasticsearch
  end # module Plugins
end # module Enscalator
