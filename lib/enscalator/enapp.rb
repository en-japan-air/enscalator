# -*- encoding : utf-8 -*-

require 'cloudformation-ruby-dsl/cfntemplate'
require_relative 'richtemplate'

module Enscalator

  # Template DSL for common enJapan application stack
  class EnAppTemplateDSL < RichTemplateDSL

    include Enscalator::Helpers

    # Mapping for subnet index start values
    START_IP_IDX_MAPPING = {
      auth_service: 16,
      cc_landing_page_generator: 20,
      enslurp: 24,
      interaction: 28,
      cc_rds: 32,
      job_posting_service: 36,
      elk: 40,
      test_instance: 252
    }

    attr_reader :region, :stack_name,
                :app_name

    # Create new EnAppTemplateDSL instance
    #
    # @param options [Hash] command-line arguments
    def initialize(options={})
      @region = options[:region]
      @stack_name = options[:stack_name]
      # application name taken from template name as default
      @app_name = self.class.name.demodulize

      super
    end

    # Get start ip index according to class name
    def get_start_ip_idx
      key = self.class.name.demodulize.underscore
      START_IP_IDX_MAPPING[key.to_sym] || fail('Need to add start ip index to START_IP_IDX_MAPPING for current template')
    end

    # Get availability zones
    def get_availability_zones
      ec2_client(region)
        .describe_availability_zones
        .availability_zones
        .select { |az| az.state == 'available' }
        .collect(&:zone_name)
        .select { |n| n =~ /[ac]$/ } # TODO: support all availability zones
    end

    # Reference to subnet in availability zone A
    def ref_application_subnet_a
      ref('ApplicationSubnetA')
    end

    # Reference to subnet in availability zone C
    def ref_application_subnet_c
      ref('ApplicationSubnetC')
    end

    # Reference to resource in availability zone A
    def ref_resource_subnet_a
      ref('ResourceSubnetA')
    end

    # Reference to resource in availability zone C
    def ref_resource_subnet_c
      ref('ResourceSubnetC')
    end

    # Reference to private security group
    def ref_private_security_group
      ref('PrivateSecurityGroup')
    end

    # Reference to resource security group
    def ref_resource_security_group
      ref('ResourceSecurityGroup')
    end

    # Reference to application security group
    def ref_application_security_group
      ref('ApplicationSecurityGroup')
    end

    # Query and pre-configure VPC parameters required for the stack
    #
    # @param stack_name [String] name of the cloudformation stack
    # @param region [String] valid Amazon AWS region
    def pre_setup(stack_name: 'enjapan-vpc', region: self.region)
      cfn = cfn_resource(cfn_client(region))
      stack = cfn.stack(stack_name)
      vpc_id = get_resource(stack, 'VpcId')
      vpc_private_security_group = get_resource(stack, 'PrivateSecurityGroup')
      vpc_private_route_tables = {'a' => get_resource(stack, 'PrivateRouteTable1'),
                                  'c' => get_resource(stack, 'PrivateRouteTable2')}

      basic_setup vpc_id,
                  get_start_ip_idx,
                  vpc_private_security_group,
                  vpc_private_route_tables
    end

    alias magic_setup pre_setup

    # Setup VPC configuration which is required in order to create stack
    #
    # @param vpc [String] the vpc_id
    # @param start_ip_idx [Integer] is the starting ip address inside the vpc subnet for this stack, i.e.
    #   "10.0.start_ip_idx.0/24"
    # (see {https://github.com/en-japan/commons/wiki/AWS-Deployment-Guideline#network-configuration})
    # @param private_security_group [String] the id of the security group with access to the NAT instances
    # @param private_route_tables [Hash] the route tables to the NAT instances
    #  private_route_tables is a hash of the form Hash, where keys are 'a' and 'c'
    #  being the suffixes of the availability zones and values are ids for route tables, e.g
    #   "{'a' => route_table_id1, 'c' => route_table_id2 }"
    def basic_setup(vpc,
                    start_ip_idx,
                    private_security_group,
                    private_route_tables)

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

      private_route_tables.map do |z, table|
        parameter "PrivateRouteTable#{z.upcase}",
                  :Description => "Route table identifier for private instances of zone #{z}",
                  :Default => table,
                  :Type => 'String',
                  :AllowedPattern => 'rtb-[a-zA-Z0-9]*',
                  :ConstraintDescription => 'must begin with rtb- followed by numbers and alphanumeric characters.'
      end

      mapping 'AWSRegionNetConfig',
              (EnJapanConfiguration::mapping_vpc_net.map do |k, v|
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
          tags: {
            'Network' => 'Private',
            'Application' => aws_stack_name,
            'immutable_metadata' => join('', '{ "purpose": "', aws_stack_name, '-app" }')
          }
        )
      end

      private_route_tables.keys.map do |z|
        subnet(
          "ResourceSubnet#{z.upcase}",
          vpc,
          find_in_map('AWSRegionNetConfig', ref('AWS::Region'), "resource#{z.upcase}"),
          availabilityZone: join('', ref('AWS::Region'), z),
          tags: {
            'Network' => 'Private',
            'Application' => aws_stack_name
          }
        )
      end

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
                         securityGroupEgress: [],
                         securityGroupIngress: [
                           {
                             :IpProtocol => 'tcp',
                             :FromPort => '22',
                             :ToPort => '22',
                             :CidrIp => '10.0.0.0/8'
                           },
                           {
                             :IpProtocol => 'tcp',
                             :FromPort => '0',
                             :ToPort => '65535',
                             :SourceSecurityGroupId => ref_application_security_group
                           },
                         ],
                         dependsOn: [],
                         tags: {}

      security_group_vpc 'ApplicationSecurityGroup',
                         'Security group of the application servers',
                         vpc,
                         securityGroupIngress: [
                           {:IpProtocol => 'tcp',
                            :FromPort => '0',
                            :ToPort => '65535',
                            :CidrIp => '10.0.0.0/8'
                           }
                         ],
                         tags: {
                           'Name' => join('-', aws_stack_name, 'app', 'sg'),
                           'Application' => aws_stack_name
                         }

    end

  end # EnAppTemplateDSL
end # module Enscalator
