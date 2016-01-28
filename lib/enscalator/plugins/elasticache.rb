module Enscalator
  module Plugins
    # Collection of methods to work with ElastiCache (Redis)
    module ElastiCache
      include Enscalator::Helpers

      # Initialize resources common for all ElastiCache instances
      # @param [Object] app_name application stack name
      # @param [Object] cache_node_type node type
      def init_cluster_resources(app_name, cache_node_type)
        resource "#{app_name}ElasticacheSubnetGroup",
                 Type: 'AWS::ElastiCache::SubnetGroup',
                 Properties: {
                   Description: 'SubnetGroup for elasticache',
                   SubnetIds: ref_resource_subnets
                 }

        resource "#{app_name}RedisSecurityGroup",
                 Type: 'AWS::EC2::SecurityGroup',
                 Properties: {
                   GroupDescription: "Redis Security Group for #{app_name}",
                   VpcId: ref_vpc_id,
                   SecurityGroupIngress: [
                     {
                       IpProtocol: 'tcp',
                       FromPort: '6379',
                       ToPort: '6389',
                       SourceSecurityGroupId: ref_application_security_group
                     }
                   ]
                 }

        resource "#{app_name}RedisParameterGroup",
                 Type: 'AWS::ElastiCache::ParameterGroup',
                 Properties: {
                   Description: "#{app_name} redis parameter group",
                   CacheParameterGroupFamily: 'redis2.8',
                   Properties: {
                     'reserved-memory': InstanceType.elasticache_instance_type.max_memory(cache_node_type) / 2
                   }
                 }
      end

      # Create ElastiCache cluster
      # @param [String] app_name application name
      # @param [String] cache_node_type instance node type
      def elasticache_cluster_init(app_name, cache_node_type: 'cache.m1.small', num_cache_nodes: 1)

        init_cluster_resources(app_name, cache_node_type)

        resource "#{app_name}RedisCluster",
                 Type: 'AWS::ElastiCache::CacheCluster',
                 Properties: {
                   VpcSecurityGroupIds: [get_att("#{app_name}RedisSecurityGroup", 'GroupId')],
                   CacheSubnetGroupName: ref("#{app_name}ElasticacheSubnetGroup"),
                   CacheParameterGroupName: ref("#{app_name}RedisParameterGroup"),
                   CacheNodeType: cache_node_type,
                   Engine: 'redis',
                   NumCacheNodes: "#{num_cache_nodes}"
                 }
      end
    end # module ElasticCache
  end # module Plugins
end # module Enscalator
