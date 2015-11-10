module Enscalator

  module Plugins

    # Collection of methods to work with Elastic Cache
    module ElasticCache
      include Enscalator::Helpers

      def elastic_cache(app_name, cache_node_type: 'cache.m1.small')
        resource "#{app_name}ElasticacheSubnetGroup", :Type => 'AWS::ElastiCache::SubnetGroup', :Properties => {
          :Description => 'SubnetGroup for elasticache',
          :SubnetIds => ref_resource_subnets
        }

        resource "#{app_name}RedisSecurityGroup", :Type => 'AWS::EC2::SecurityGroup', :Properties => {
          :GroupDescription => 'Redis Security Group',
          :VpcId => vpc.id,
          :SecurityGroupIngress => [
            {
              :IpProtocol => 'tcp',
              :FromPort => '6379',
              :ToPort => '6389',
              :SourceSecurityGroupId => ref_application_security_group
            }
          ],
        }
        resource "#{app_name}RedisParameterGroup", :Type =>  'AWS::ElastiCache::ParameterGroup', :Properties => {
          :Description => "#{app_name} redis parameter group",
          :CacheParameterGroupFamily => 'redis2.8',
          :Properties => {
            :'reserved-memory' => InstanceType.elastic_cache_instance_type.max_memory(cache_node_type) / 2
          }

        }
        resource "#{app_name}Redis", :Type => 'AWS::ElastiCache::CacheCluster', :Properties => {
          :VpcSecurityGroupIds => [get_att("#{app_name}RedisSecurityGroup", 'GroupId')],
          :CacheSubnetGroupName => ref("#{app_name}ElasticacheSubnetGroup"),
          :CacheParameterGroupName => ref("#{app_name}RedisParameterGroup"),
          :CacheNodeType => cache_node_type,
          :Engine => 'redis',
          :NumCacheNodes => '1'
        }
      end

    end # module ElasticCache
  end # module Plugins
end # module Enscalator
