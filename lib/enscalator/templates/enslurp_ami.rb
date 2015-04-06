module Enscalator

  # Namespace for cloudformation templates
  module Templates

    # Template for EnSlurp
    class EnslurpAmi < Enscalator::EnAppTemplateDSL
      def tpl

        pre_run do
          magic_setup stack_name: 'enjapan-vpc',
            region: @options[:region],
            start_ip_idx: 32
        end

        description 'Enslurp network and database infrastructure'

        parameter_keyname 'Enslurp'

        parameter_instance_class 'Enslurp',
          default: 'm3.medium'

        parameter 'EnslurpAMI',
          :Description => 'Id of the enslurp AMI',
          :Type => 'String'

        resource 'ElasticacheSubnetGroup', :Type => 'AWS::ElastiCache::SubnetGroup', :Properties => {
          :Description => 'SubnetGroup for elasticache',
          :SubnetIds => [
            ref_resource_subnet_a,
            ref_resource_subnet_c
          ]
        }

        instance_vpc('Enslurp', ref('EnslurpAMI'),
                     ref_application_subnet_a,
                     [ref_private_security_group, ref_application_security_group],
                     properties: {
                       :KeyName => ref('EnslurpKeyName'),
                       :InstanceType => ref('EnslurpInstanceClass'),
                       :IamInstanceProfile => iam_s3_instance_profile
                     })

        resource 'EnslurpRedisParameterGroup', :Type =>  'AWS::ElastiCache::ParameterGroup', :Properties => {
          :Description => 'Enslurp redis parameter group',
          :CacheParameterGroupFamily => 'redis2.8',
          :Properties => {
            :'reserved-memory' => 7235174400 # cache.r3.large.maxmemory / 2
          }
        }

        resource 'Redis', :Type => 'AWS::ElastiCache::CacheCluster', :Properties => {
          :VpcSecurityGroupIds => [get_att('ResourceSecurityGroup', 'GroupId')],
          :CacheSubnetGroupName => ref('ElasticacheSubnetGroup'),
          :CacheParameterGroupName => ref('EnslurpRedisParameterGroup'),
          :CacheNodeType => 'cache.r3.large',
          :Engine => 'redis',
          :NumCacheNodes => '1',
          :Port => 6379
        }

        post_run do
          region = @options[:region]
          stack_name = @options[:stack_name]
          client = Aws::CloudFormation::Client.new(region: region)
          cfn = Aws::CloudFormation::Resource.new(client: client)

          stack = wait_stack(cfn, stack_name)
          redis_cache_id = get_resource(stack, 'Redis')

          elasticache = Aws::ElastiCache::Client.new(region: region)
          redis_cluster = elasticache.describe_cache_clusters(cache_cluster_id: redis_cache_id, show_cache_node_info: true)

          upsert_dns_record(
            zone_name: 'enjapan.local.',
            record_name: "redis.#{stack_name}.enjapan.local.",
            type: 'CNAME',
            values: [redis_cluster[:cache_clusters].first[:cache_nodes].first.endpoint.address])
        end
      end
    end
  end
end
