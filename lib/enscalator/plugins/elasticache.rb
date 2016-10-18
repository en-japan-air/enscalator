module Enscalator
  module Plugins
    # Collection of methods to work with ElastiCache (Redis)
    module Elasticache
      include Enscalator::Helpers

      # Generates magic number (sha256 hex digest) from given Hash
      # @param [Object] input used for digest generation
      # @return [String]
      def magic_number(input)
        str = if input.is_a?(String)
                input
              elsif input.is_a?(Array)
                input.flatten.map(&:to_s).sort.join('&')
              elsif input.is_a?(Hash)
                flatten_hash(input).map { |k, v| "#{k}=#{v}" }.sort.join('&')
              else
                fail("Not supported input format: #{input.class}")
              end
        Digest::SHA256.hexdigest(str)
      end

      # Initialize resources common for all ElastiCache instances
      # @param [Object] app_name application stack name
      # @param [Object] cache_node_type node type
      def init_cluster_resources(app_name, cache_node_type, param_group_seed: nil, **properties)
        subnet_group_name = "#{app_name}ElasticacheSubnetGroup"
        resource subnet_group_name,
                 Type: 'AWS::ElastiCache::SubnetGroup',
                 Properties: {
                   Description: 'SubnetGroup for elasticache',
                   SubnetIds: ref_resource_subnets
                 }

        security_group_name =
          security_group_vpc "#{app_name}RedisSecurityGroup",
                             "Redis Security Group for #{app_name}",
                             ref_vpc_id,
                             security_group_ingress: [
                               {
                                 IpProtocol: 'tcp',
                                 FromPort: '6379',
                                 ToPort: '6389',
                                 SourceSecurityGroupId: ref_application_security_group
                               }
                             ],
                             tags: {
                               Name: join('-', aws_stack_name, 'res', 'sg'),
                               Application: aws_stack_name
                             }

        parameter_group_required_props = {
          'reserved-memory': Core::InstanceType.elasticache_instance_type.max_memory(cache_node_type) / 2
        }

        parameter_group_props = (
        if !properties.nil? && properties.key?(:parameter_group_properties)
          properties[:parameter_group_properties]
        else
          {}
        end).merge(parameter_group_required_props)

        # TODO: remove this workaround when related template gets fixed
        parameter_group_name = if param_group_seed
                                 "#{app_name}RedisParameterGroup#{param_group_seed}"
                               else
                                 "#{app_name}RedisParameterGroup#{magic_number(parameter_group_props)}"
                               end

        resource parameter_group_name,
                 Type: 'AWS::ElastiCache::ParameterGroup',
                 Properties: {
                   Description: "#{app_name} redis parameter group",
                   CacheParameterGroupFamily: 'redis2.8',
                   Properties: parameter_group_props
                 }

        {
          subnet_group: subnet_group_name,
          security_group: security_group_name,
          parameter_group: parameter_group_name
        }
      end

      # Create ElastiCache cluster
      # @param [String] app_name application name
      # @param [String] cache_node_type instance node type
      # @param [Integer] num_cache_nodes number of nodes to create
      def elasticache_cluster_init(app_name, cache_node_type: 'cache.m1.small', num_cache_nodes: 1)
        cluster_resources = init_cluster_resources(app_name, cache_node_type)

        resource_name = "#{app_name}RedisCluster"
        resource resource_name,
                 Type: 'AWS::ElastiCache::CacheCluster',
                 Properties: {
                   Engine: 'redis',
                   NumCacheNodes: "#{num_cache_nodes}",
                   CacheNodeType: cache_node_type,
                   CacheSubnetGroupName: ref("#{app_name}ElasticacheSubnetGroup"),
                   CacheParameterGroupName: ref(cluster_resources[:parameter_group]),
                   VpcSecurityGroupIds: [get_att("#{app_name}RedisSecurityGroup", 'GroupId')]
                 }
        resource_name

        # Unable to get created resource endpoint and port with Fn::GetAtt for engine == redis
        # For more details see here:
        # http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-elasticache-cache-cluster.html
      end

      # Create ElastiCache replication group
      # @param [String] app_name application name
      # @param [String] cache_node_type instance node type
      def elasticache_repl_group_init(app_name, cache_node_type: 'cache.t2.small',
                                      num_cache_clusters: 2, seed: nil, **properties)
        if %w(t1).map { |t| cache_node_type.include?(t) }.include?(true)
          fail "T1 instance types are not supported, got '#{cache_node_type}'"
        end

        cluster_properties =
          !properties.nil? && properties.key?(:cluster_properties) ? properties[:cluster_properties] : {}

        cluster_resources = init_cluster_resources(app_name,
                                                   cache_node_type,
                                                   param_group_seed: seed,
                                                   parameter_group_properties: cluster_properties)

        resource_name = "#{app_name}RedisReplicationGroup"
        resource resource_name,
                 Type: 'AWS::ElastiCache::ReplicationGroup',
                 Properties: {
                   Engine: 'redis',
                   ReplicationGroupDescription: "Redis Replication group for #{app_name}",
                   AutomaticFailoverEnabled: num_cache_clusters > 1 ? 'true' : 'false',
                   NumCacheClusters: num_cache_clusters,
                   CacheNodeType: cache_node_type,
                   CacheSubnetGroupName: ref("#{app_name}ElasticacheSubnetGroup"),
                   CacheParameterGroupName: ref(cluster_resources[:parameter_group]),
                   SecurityGroupIds: [
                     get_att("#{app_name}RedisSecurityGroup", 'GroupId'),
                     ref_private_security_group
                   ]
                 }.merge(properties.reject { |k, _v| k == :cluster_properties })

        output "#{app_name}RedisReplicationGroup",
               Description: "Redis ReplicationGroup #{app_name}",
               Value: ref("#{app_name}RedisReplicationGroup")

        output "#{app_name}RedisPrimaryEndpointAddress",
               Description: "Redis Primary Endpoint Address #{app_name}",
               Value: get_att(resource_name, 'PrimaryEndPoint.Address')

        output "#{app_name}RedisPrimaryEndpointPort",
               Description: "Redis Primary Endpoint Port #{app_name}",
               Value: get_att(resource_name, 'PrimaryEndPoint.Port')

        output "#{app_name}RedisReadOnlyEndpointAddresses",
               Description: "Redis ReadOnly Endpoint Addresses #{app_name}",
               Value: get_att(resource_name, 'ReadEndPoint.Addresses')

        output "#{app_name}RedisReadOnlyEndpointPorts",
               Description: "Redis ReadOnly Endpoint Ports #{app_name}",
               Value: get_att(resource_name, 'ReadEndPoint.Ports')

        resource_name
      end
    end # module ElasticCache
  end # module Plugins
end # module Enscalator
