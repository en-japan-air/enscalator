# -*- encoding : utf-8 -*-

require 'cloudformation-ruby-dsl/cfntemplate'
require_relative 'richtemplate'

module Enscalator

  # Template DSL for common enJapan application stack
  class EnAppTemplateDSL < RichTemplateDSL

    include Enscalator::Helpers

    attr_reader :app_name

    # Create new EnAppTemplateDSL instance
    #
    # @param [Hash] options command-line arguments
    def initialize(options={})
      # application name taken from template name by default
      @app_name = self.class.name.demodulize

      super
    end

    # Get vpc stack
    #
    # @return [Aws::CloudFormation::Stack] stack instance of vpc stack
    def vpc_stack
      @vpc_stack ||= cfn_resource(cfn_client(region)).stack(vpc_stack_name)
    end

    # Get vpc
    #
    # @return [Aws::EC2::Vpc] vpc instance
    def vpc
      @vpc ||= Aws::EC2::Vpc.new(id: get_resource(stack, 'VpcId'), region: region)
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

    # Allocate net config dynamically
    def allocate_net_config
      all_subnets = IPAddress(EnJapanConfiguration.mapping_vpc_net[region.to_sym]).subnet(24).map(&:to_string)
      current_max_idx = vpc.subnets.collect(&:cidr_block).map { |subnet| all_subnets.index(subnet) + 1 }.sort.last
      subnets = all_subnets.drop(current_max_idx).take(2 * availability_zones.size)

      availability_zones
        .map { |suffix, _| %W( application#{suffix.upcase} resource#{suffix.upcase} ) }
        .flatten
        .zip(subnets)
        .to_h
    end

    # Setup VPC configuration which is required in order to create stack
    def basic_setup
      parameter 'VpcId',
                :Description => 'The Id of the VPC',
                :Default => vpc.id,
                :Type => 'String',
                :AllowedPattern => 'vpc-[a-zA-Z0-9]*',
                :ConstraintDescription => 'must begin with vpc- followed by numbers and alphanumeric characters.'

      parameter 'PrivateSecurityGroup',
                :Description => 'Security group identifier of private instances',
                :Default => get_resource(vpc_stack, 'PrivateSecurityGroup'),
                :Type => 'String',
                :AllowedPattern => 'sg-[a-zA-Z0-9]*',
                :ConstraintDescription => 'must begin with sg- followed by numbers and alphanumeric characters.'

      net_config = allocate_net_config

      availability_zones.each do |suffix, _|
        parameter "PrivateRouteTable#{suffix.upcase}",
                  :Description => "Route table identifier for private instances of zone #{suffix}",
                  :Default => get_resource(vpc_stack, "PrivateRouteTable#{suffix.upcase}"),
                  :Type => 'String',
                  :AllowedPattern => 'rtb-[a-zA-Z0-9]*',
                  :ConstraintDescription => 'must begin with rtb- followed by numbers and alphanumeric characters.'

        subnet "ApplicationSubnet#{suffix.upcase}",
               vpc,
               net_config["application#{suffix.upcase}"],
               availabilityZone: "#{region}#{suffix}",
               tags: {
                 'Network' => 'Private',
                 'Application' => aws_stack_name,
                 'immutable_metadata' => join('', '{ "purpose": "', aws_stack_name, '-app" }')
               }

        subnet "ResourceSubnet#{suffix.upcase}",
               vpc,
               net_config["resource#{suffix.upcase}"],
               availabilityZone: "#{region}#{suffix}",
               tags: {
                 'Network' => 'Private',
                 'Application' => aws_stack_name
               }

        resource "RouteTableAssociation#{suffix.upcase}",
                 :Type => 'AWS::EC2::SubnetRouteTableAssociation',
                 :Properties => {
                   :RouteTableId => ref("PrivateRouteTable#{suffix.upcase}"),
                   :SubnetId => ref("ApplicationSubnet#{suffix.upcase}"),
                 }
      end

      security_group_vpc 'ResourceSecurityGroup',
                         'Enable internal access with ssh',
                         vpc.id,
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
                         vpc.id,
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
