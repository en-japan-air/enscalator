require 'cloudformation-ruby-dsl/cfntemplate'
require_relative 'richtemplate'

module Enscalator
  class EnAppTemplateDSL < RichTemplateDSL

    def ref_application_subnet_a
      ref('ApplicationSubnetA')
    end

    def ref_application_subnet_c
      ref('ApplicationSubnetC')
    end

    def ref_resource_subnet_a
      ref('ResourceSubnetA')
    end

    def ref_resource_subnet_c
      ref('ResourceSubnetC')
    end

    def ref_private_security_group
      ref('PrivateSecurityGroup')
    end

    def ref_resource_security_group
      ref('ResourceSecurityGroup')
    end

    def ref_application_security_group
      ref('ApplicationSecurityGroup')
    end

    def client(region)
      raise RuntimeError, 'Unable to proceed without region' if region && region.empty?
      Aws::CloudFormation::Client.new(region: region)
    end

    def get_cfn(client)
      raise RuntimeError, 'Unable to query resource without client' unless client
      Aws::CloudFormation::Resource.new(client: client)
    end

    # Do like with magic_setup, but without basic_setup and post_run hook
    def pre_setup(stack_name: 'enjapan-vpc', region: 'us-east-1', start_ip_idx: 16)
      cfn = get_cfn(client(region))
      stack = cfn.stack(stack_name)
      vpc_id = select_output(stack.outputs, 'VpcId')
      private_security_group = select_output(stack.outputs, 'PrivateSecurityGroup')
      private_route_tables = { 'a' => get_resource(stack, 'PrivateRouteTable1'),
                               'c' => get_resource(stack, 'PrivateRouteTable2') }

      flat_setup vpc: vpc_id,
                 region: region,
                 start_ip_idx: start_ip_idx,
                 private_security_group: private_security_group,
                 private_route_tables: private_route_tables
    end

    def flat_setup(vpc: nil,
                   region: nil,
                   start_ip_idx: 16,
                   private_security_group: '',
                   private_route_tables: {})

      parameter 'VpcId',
                :Description => 'The Id of the VPC',
                :Default => vpc,
                :Type => 'String',
                :AllowedPattern => 'vpc-[a-zA-Z0-9]*',
                :ConstraintDescription => 'must begin with vpc- followed by numbers and alphanumeric characters.'

      parameter 'PrivateSecurityGroup',
                :Description => 'Security group identifier of private instances',
                :Default => private_security_group,
                :Type => 'String',
                :AllowedPattern => 'sg-[a-zA-Z0-9]*',
                :ConstraintDescription => 'must begin with sg- followed by numbers and alphanumeric characters.'

      private_route_tables.map do |z,table|
        parameter "PrivateRouteTable#{z.upcase}",
                  :Description => "Route table identifier for private instances of zone #{z}",
                  :Default => table,
                  :Type => 'String',
                  :AllowedPattern => 'rtb-[a-zA-Z0-9]*',
                  :ConstraintDescription => 'must begin with rtb- followed by numbers and alphanumeric characters.'
      end

      mapping 'AWSRegionNetConfig',
        (EnJapanConfiguration::mapping_vpc_net.map do |k,v|
          subs = IPAddress(v[:VPC]).subnet(24).map(&:to_string).drop(start_ip_idx).take(4)
          {
            k => {
              :applicationA => subs[0], :applicationC => subs[1],
              :resourceA => subs[2], :resourceC => subs[3]
            }
          }
        end.reduce(:merge).with_indifferent_access)

      # TODO: move this to separate elb plugin
      private_route_tables.keys.map do |z|
        subnet(
          "ApplicationSubnet#{z.upcase}",
          vpc,
          find_in_map('AWSRegionNetConfig', ref('AWS::Region'), "application#{z.upcase}"),
          availabilityZone: join('', ref('AWS::Region'), z),
          tags:{
            'Network' => 'Private',
            'Application' => aws_stack_name,
            'immutable_metadata' => join('','{ "purpose": "', aws_stack_name, '-app" }')
          }
        )
      end

      private_route_tables.keys.map do |z|
        subnet(
          "ResourceSubnet#{z.upcase}",
          vpc,
          find_in_map('AWSRegionNetConfig', ref('AWS::Region'), "resource#{z.upcase}"),
          availabilityZone: join('', ref('AWS::Region'), z),
          tags:{
            'Network' => 'Private',
            'Application' => aws_stack_name
          }
        )
      end

      # TODO: move this to separate elb plugin
      private_route_tables.keys.map do |z|
        resource "RouteTableAssociation#{z.upcase}",
                 :Type => 'AWS::EC2::SubnetRouteTableAssociation',
                 :Properties => {
                     :RouteTableId => ref("PrivateRouteTable#{z.upcase}"),
                     :SubnetId => ref("ApplicationSubnet#{z.upcase}"),
                 }
      end

      security_group_vpc 'ResourceSecurityGroup',
                         'Enable internal access with ssh',
                         ref_vpc_id,
                         securityGroupEgress:[],
                         securityGroupIngress: [
                           {
                             :IpProtocol => 'tcp',
                             :FromPort => '22',
                             :ToPort => '22',
                             :CidrIp => EnJapanConfiguration.mapping_vpc_net[region][:VPC]
                           },
                           {
                             :IpProtocol => 'tcp',
                             :FromPort => '0',
                             :ToPort => '65535',
                             :SourceSecurityGroupId => ref_application_security_group # TODO: move this to elb plugin
                           },
                         ],
                         dependsOn:[],
                         tags:{}

      # TODO: move this to elb plugin
      security_group_vpc 'ApplicationSecurityGroup',
                         'Security group of the application servers',
                         ref_vpc_id,
                         securityGroupIngress: [
                           { :IpProtocol => 'tcp',
                             :FromPort => '0',
                             :ToPort => '65535',
                             :CidrIp => EnJapanConfiguration.mapping_vpc_net[region][:VPC]
                           },
                         ],
                         tags: {
                             'Name' => join('-', aws_stack_name, 'app', 'sg'),
                             'Application' => aws_stack_name
                         }

    end

    # TODO: move this logic to elb plugin
    # Do exactly like basic_setup but the vpc_id, private_security_group,
    # and the route tables are automatically filled from the stack stack_name
    def magic_setup(stack_name: 'enjapan-vpc', region: 'us-east-1', start_ip_idx: 16)
      cfn = get_cfn(client(region))
      stack = cfn.stack(stack_name)
      vpc_id = select_output(stack.outputs, 'VpcId')
      private_security_group = select_output(stack.outputs, 'PrivateSecurityGroup')
      private_route_tables = { 'a' => get_resource(stack, 'PrivateRouteTable1'),
                               'c' => get_resource(stack, 'PrivateRouteTable2') }

      basic_setup vpc: vpc_id,
        start_ip_idx: start_ip_idx,
        private_security_group: private_security_group,
        private_route_tables: private_route_tables                                                                                                       

      post_run do
        cfn = get_cfn(client(region))
        stack = wait_stack(cfn, @options[:stack_name])
        elb_name = select_output(stack.outputs, 'LoadBalancerDnsName')
        upsert_dns_record(
          zone_name: 'enjapan.local.',
          record_name: "elb.#{@options[:stack_name]}.enjapan.local.",
          type: 'CNAME', region: region, values: [elb_name]
        )
      end

    end

    # TODO: deprecated, move
    # vpc is the vpc_id
    # start_ip_idx is the starting ip address inside the vpc subnet for this stack (i.e 10.0.#{start_ip_idx}.0/24)
    #   (see M https://github.com/en-japan/commons/wiki/AWS-Deployment-Guideline#network-configuration)
    # private_security_group is the id of the security group with access to the NAT instances
    # private_route_tables are the route tables to the NAT instances
    # Private_route_tables is a hash of the form {'a' => route_table_id1, 'c' => route_table_id2}
    #   a and c being the suffixes of the availability zones
    def basic_setup(vpc: nil, start_ip_idx: 16,
                    private_security_group: '',
                    private_route_tables: {})
      parameter 'VpcId',
        :Description => 'The Id of the VPC',
        :Default => vpc,
        :Type => 'String',
        :AllowedPattern => 'vpc-[a-zA-Z0-9]*',
        :ConstraintDescription => 'must begin with vpc- followed by numbers and alphanumeric characters.'

      parameter 'PrivateSecurityGroup',
        :Description => 'Security group identifier of private instances',
        :Default => private_security_group,
        :Type => 'String',
        :AllowedPattern => 'sg-[a-zA-Z0-9]*',
        :ConstraintDescription => 'must begin with sg- followed by numbers and alphanumeric characters.'

      private_route_tables.map do |z,table|
        parameter "PrivateRouteTable#{z.upcase}",
          :Description => "Route table identifier for private instances of zone #{z}",
          :Default => table,
          :Type => 'String',
          :AllowedPattern => 'rtb-[a-zA-Z0-9]*',
          :ConstraintDescription => 'must begin with rtb- followed by numbers and alphanumeric characters.'
      end

      mapping 'AWSRegionNetConfig',
        (EnJapanConfiguration::mapping_vpc_net.map do |k,v|
        subs = IPAddress(v[:VPC]).subnet(24).map(&:to_string).drop(start_ip_idx).take(4)
        {
          k => {
            :applicationA => subs[0], :applicationC => subs[1],
            :resourceA => subs[2], :resourceC => subs[3]
          }
        }
      end.reduce(:merge).with_indifferent_access)

      private_route_tables.keys.map do |z|
        subnet(
          "ApplicationSubnet#{z.upcase}",
          vpc,
          find_in_map('AWSRegionNetConfig', ref('AWS::Region'), "application#{z.upcase}"),
          availabilityZone: join('', ref('AWS::Region'), z),
          tags:{
            'Network' => 'Private',
            'Application' => aws_stack_name,
            'immutable_metadata' => join('','{ "purpose": "', aws_stack_name, '-app" }')
          }
        )
      end

      private_route_tables.keys.map do |z|
        subnet(
          "ResourceSubnet#{z.upcase}",
          vpc,
          find_in_map('AWSRegionNetConfig', ref('AWS::Region'), "resource#{z.upcase}"),
          availabilityZone: join('', ref('AWS::Region'), z),
          tags:{
            'Network' => 'Private',
            'Application' => aws_stack_name
          }
        )
      end

      private_route_tables.keys.map do |z|
        resource "RouteTableAssociation#{z.upcase}", :Type => 'AWS::EC2::SubnetRouteTableAssociation', :Properties => {
          :RouteTableId => ref("PrivateRouteTable#{z.upcase}"),
          :SubnetId => ref("ApplicationSubnet#{z.upcase}"),
        }
      end

      security_group_vpc 'ResourceSecurityGroup',
        'Enable internal access to interaction service database',
        ref_vpc_id,
        securityGroupEgress:[],
        securityGroupIngress: [
          { :IpProtocol => 'tcp', :FromPort => '22', :ToPort => '22', :CidrIp => '10.0.0.0/8' },
          {
            :IpProtocol => 'tcp',
            :FromPort => '0',
            :ToPort => '65535',
            :SourceSecurityGroupId => ref_application_security_group,
          },
        ], dependsOn:[], tags:{}


      security_group_vpc 'ApplicationSecurityGroup',
        'Security group of the application servers',
        vpc,
        securityGroupIngress: [
          { :IpProtocol => 'tcp',
            :FromPort => '0',
            :ToPort => '65535',
            :CidrIp => '10.0.0.0/8' },
          { :IpProtocol => 'tcp',
            :FromPort => ref('WebServerPort'),
            :ToPort => ref('WebServerPort'),
            :SourceSecurityGroupId => ref_private_security_group },
        ],
        tags: {
          'Name' => join('-', aws_stack_name, 'app', 'sg'),
          'Application' => aws_stack_name
        }

      parameter 'WebServerPort',
        :Description => 'TCP/IP Port for the web service',
        :Type => 'Number',
        :MinValue => '0',
        :MaxValue => '65535',
        :ConstraintDescription => 'must be an integer between 0 and 65535.'

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

      output "LoadBalancerDnsName",
        :Description => "LoadBalancer DNS Name",
        :Value => get_att('LoadBalancer', 'DNSName')

    end
  end
end
