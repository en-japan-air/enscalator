# -*- encoding : utf-8 -*-

module Enscalator
  module Plugins

    # Elasticsearch related configuration
    module Elasticsearch

      # Create new elasticsearch instance
      #
      # @param db_name [String] database name
      # @param allocated_storage [Integer] size of instance primary storage
      # @param instance_class [String] instance class (type)
      def elasticsearch_init(db_name,
                             allocated_storage: 5,
                             instance_class: 't2.medium')
        @elasticsearch_mapping ||=
          mapping 'AWSElasticsearchAMI', {
            :'us-east-1' => { :amd64 => 'ami-041c4e6c' },
            :'us-west-2' => { :amd64 => 'ami-315c7d01' },
            :'us-west-1' => { :amd64 => 'ami-f726c3b3' },
            :'eu-west-1' => { :amd64 => 'ami-b51d8ac2' },
            :'ap-southeast-1' => { :amd64 => 'ami-62645330' },
            :'ap-southeast-2' => { :amd64 => 'ami-6b9deb51' },
            :'ap-northeast-1' => { :amd64 => 'ami-a952b0a9' },
            :'sa-east-1' => { :amd64 => 'ami-e9259bf4' },
            :Security => { :amd64 => 'Group' },
        }
          parameter_keyname "Elasticsearch#{db_name}"

          parameter_allocated_storage "Elasticsearch#{db_name}",
            default: allocated_storage,
            min: 5,
            max: 1024

          parameter_instance_class "Elasticsearch#{db_name}",
                                   default: instance_class,
                                   allowed_values: %w(t2.micro t2.small t2.medium m3.medium m3.large m3.xlarge  m3.2xlarge)

          instance_vpc("Elasticsearch#{db_name}",
                       find_in_map('AWSElasticsearchAMI', ref('AWS::Region'), 'amd64'),
                       ref_resource_subnet_a,
                       [ref_private_security_group, ref_resource_security_group],
                       dependsOn:[], properties: {
                         :KeyName => ref("Elasticsearch#{db_name}KeyName"),
                         :InstanceType => ref("Elasticsearch#{db_name}InstanceClass")
                       })
      end
    end # module Elasticsearch
  end # module Plugins
end # module Enscalator
