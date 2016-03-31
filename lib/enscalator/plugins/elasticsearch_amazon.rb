module Enscalator
  module Plugins
    # Amazon Elasticsearch Service (Amazon ES)
    module ElasticsearchAmazon
      # Create new service instance
      # @param [String] cluster_name name of the cluster resource
      # @param [Hash] properties additional parameters for cluster configuration
      def elasticsearch_init(cluster_name, properties: {})
        cluster_properties = {
          AccessPolicies: {
            Version: '2012-10-17',
            Statement: [
              {
                Effect: 'Allow',
                Principal: {
                  AWS: '*'
                }
              }
            ]
          },
          AdvancedOptions: {
            'rest.action.multi.allow_explicit_index': 'true'
          },
          EBSOptions: {
            EBSEnabled: true,
            Iops: 0,
            VolumeSize: 100,
            VolumeType: 'gp2'
          },
          ElasticsearchClusterConfig: {
            InstanceCount: '1',
            InstanceType: 'm3.medium.elasticsearch'
          },
          SnapshotOptions: {
            AutomatedSnapshotStartHour: '0'
          }
        }

        # do not modify properties passed from template
        props = properties.deep_dup

        default_tags = [
          {
            Key: 'ClusterName',
            Value: cluster_name.downcase
          }
        ]

        if props.key?(:Tags) && !props[:Tags].empty?
          props[:Tags].concat(default_tags)
        else
          props[:Tags] = default_tags
        end

        resource cluster_name,
                 Type: 'AWS::Elasticsearch::Domain',
                 Properties: cluster_properties.merge(props)

        output "#{cluster_name}ResourceID",
               Description: "#{cluster_name} ResourceID",
               Value: ref(cluster_name)

        output "#{cluster_name}DomainArn",
               Description: "#{cluster_name} DomainArn",
               Value: get_att(cluster_name, 'DomainArn')

        output "#{cluster_name}DomainEndpoint",
               Description: "#{cluster_name} DomainEndpoint",
               Value: get_att(cluster_name, 'DomainEndpoint')

        cluster_name
      end
    end # module ElasticsearchAmazon
  end # module Plugins
end # module Enscalator
