
module Enscalator
  module Templates
    class JobPosting < Enscalator::EnAppTemplateDSL
      def initialize(options={})
        @options = options
        block = Proc.new { tpl }
        super(&block)
      end

      def tpl
        pre_run do
          region = @options[:region]
          client = Aws::CloudFormation::Client.new(region: region)
          cfn = Aws::CloudFormation::Resource.new(client: client)
          stack = cfn.stack('enjapan-vpc')
          vpc_id = select_output(stack.outputs, 'VpcId')
          private_security_group = select_output(stack.outputs, 'PrivateSecurityGroup')
          private_route_tables = { 'a' => get_resource(stack, 'PrivateRouteTable1'),
                                   'c' => get_resource(stack, 'PrivateRouteTable2') }

          basic_setup vpc: vpc_id,
            start_ip_idx: 20,
            private_security_group: private_security_group,
            private_route_tables: private_route_tables
        end

        post_run do
          region = @options[:region]
          stack_name = @options[:stack_name]
          client = Aws::CloudFormation::Client.new(region: region)
          cfn = Aws::CloudFormation::Resource.new(client: client)

          stack = wait_stack(cfn, stack_name)
          ipaddr = get_resource(stack, 'CouchbasePrivateIpAddress')

          upsert_dns_record(zone_name: 'enjapan.local.',
                            record_name: "couchbase.#{stack_name}.enjapan.local.",
          type: 'A', region: region, values: [ipaddr])
        end

        description 'JobPosting service network and database infrastructure'

        parameter 'KeyName',
          :Description => 'Name of the ssh key pair',
          :Type => 'String',
          :MinLength => '1',
          :MaxLength => '64',
          :AllowedPattern => '[a-zA-Z][a-zA-Z0-9]*',
          :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'

        parameter 'WebServerPort',
          :Description => 'TCP/IP Port for the web service',
          :Type => 'Number',
          :MinValue => '0',
          :MaxValue => '65535',
          :ConstraintDescription => 'must be an integer between 0 and 65535.'

        parameter_allocated_storage 'DB',
          default: 5,
          min: 5,
          max: 1024

        parameter_instance_class 'DB', default: 'm1.medium',
          allowed_values: %w(m1.medium m1.large m1.xlarge m2.xlarge
                              m2.2xlarge m2.4xlarge c1.medium c1.xlarge
                              cc1.4xlarge cc2.8xlarge cg1.4xlarge)

        mapping 'AWSCouchbaseAMI',  Enscalator::Couchbase::mapping_ami

        resource 'LoadBalancer', :Type => 'AWS::ElasticLoadBalancing::LoadBalancer', :Properties => {
          :LoadBalancerName => join('-', aws_stack_name, 'elb'),
          :Listeners => [
            {
              :LoadBalancerPort => '80',
              :InstancePort => ref('WebServerPort'),
              :Protocol => 'HTTP',
            },
          ],
          :HealthCheck => {
            :Target => join('', 'HTTP:', ref_web_server_port, '/'),
            :HealthyThreshold => '3',
            :UnhealthyThreshold => '5',
            :Interval => '30',
            :Timeout => '5',
          },
          :Scheme => 'internal',
          :SecurityGroups => [ ref_private_security_group ],
          :Subnets => [
            ref_resource_subnet_a,
            ref_resource_subnet_c
          ],
            :Tags => [
              {
                :Key => 'Name',
                :Value => join('-', aws_stack_name, 'elb'),
              },
              {
                :Key => 'Application',
                :Value => aws_stack_name,
              },
              { :Key => 'Network', :Value => 'Private' },
          ],
        }

        security_group_vpc 'CouchbaseSecurityGroup',
          'Enable internal access to interaction service database',
          ref_vpc_id,
          securityGroupEgress:[],
          securityGroupIngress: [
            { :IpProtocol => 'tcp', :FromPort => '22', :ToPort => '22', :CidrIp => '0.0.0.0/0' },
            {
              :IpProtocol => 'tcp',
              :FromPort => '0',
              :ToPort => '65535',
              :SourceSecurityGroupId => ref_application_security_group,
            },
          ], dependsOn:[], tags:{}

            instance_vpc('Couchbase',
                         find_in_map('AWSCouchbaseAMI', ref('AWS::Region'), 'amd64'),
                         ref_resource_subnet_a,
                         [ref_private_security_group, ref('CouchbaseSecurityGroup')],
                         dependsOn:[], properties: {
                           :KeyName => ref_key_name,
                           :InstanceType => ref_db_instance_class
                         })

                         output "LoadBalancerDnsName",
                           :Description => "LoadBalancer DNS Name",
                           :Value => get_att('LoadBalancer', 'DNSName')

      end
    end
  end
end
