module Enscalator

  # Namespace for enscalator plugins
  module Plugins

    # Internet facing ELB instance
    module Elb

      # Create new ELB instance
      #
      # @param stack_name [String] must be stack name from @options[:stack_name]
      # @param region [String] must be region from @options[:region]
      # @param elb_name [String, Hash] ELB instance name - can be either String or Fn::Join
      # @param web_server_port [Integer] application port to which ELB redirects traffic
      # @param zone_name [String] zone name attached to the vpc
      def elb_init(stack_name,
                   region,
                   elb_name: join('-', aws_stack_name, 'elb'),
                   web_server_port: 9000,
                   zone_name: 'enjapan.local.')

        parameter 'WebServerPort',
                  :Description => 'TCP/IP Port for the web service',
                  :Default => web_server_port,
                  :Type => 'Number',
                  :MinValue => '0',
                  :MaxValue => '65535',
                  :ConstraintDescription => 'must be an integer between 0 and 65535.'

        # TODO: this has to be fixed, otherwise traffic from load-balancer is not allowed
        # resource 'WebServerPortSecurityGroupId', :Type => 'AWS::EC2::SecurityGroupIngress',
        #          :Properties => {
        #              :IpProtocol => 'tcp',
        #              :FromPort => ref('WebServerPort'),
        #              :ToPort => ref('WebServerPort'),
        #              :SourceSecurityGroupId => ref_private_security_group
        #          },
        #          :DependsOn => 'ApplicationSecurityGroup'

        resource 'LoadBalancer', :Type => 'AWS::ElasticLoadBalancing::LoadBalancer',
                 :Properties => {
                     :LoadBalancerName => elb_name,
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
                             :Value => elb_name
                         },
                         {
                             :Key => 'Application',
                             :Value => aws_stack_name
                         },
                         { :Key => 'Network', :Value => 'Private' },
                     ],
                 }

        output 'LoadBalancerDnsName',
               :Description => 'LoadBalancer DNS Name',
               :Value => get_att('LoadBalancer', 'DNSName')

        post_run do
          cfn = cfn_client(region)
          stack = wait_stack(cfn, stack_name)
          elb_name = get_resource(stack, 'LoadBalancerDnsName')
          upsert_dns_record(
              zone_name: zone_name,
              record_name: "elb.#{stack_name}.#{zone_name}",
              type: 'CNAME', values: [elb_name]
          )
        end
      end

    end # module Elb
  end # module Plugins
end # module Enscalator
