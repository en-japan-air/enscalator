require 'cloudformation-ruby-dsl/cfntemplate'
require_relative 'richtemplate'

def en_app(vpc: nil,
           start_ip_idx: 16,
           private_route_tables: {},
           private_security_group: '',
           &block)
  Enscalator::EnAppTemplateDSL.new(
    vpc,
    start_ip_idx,
    private_route_tables,
    private_security_group,
    &block)
end

module Enscalator
  class EnAppTemplateDSL < RichTemplateDSL
    def initialize(vpc,
                   start_ip_idx,
                   private_route_tables,
                   private_security_group,
                   &block)

      super(&block)
      create_app(vpc, start_ip_idx, private_route_tables,private_security_group)
    end

    def create_app(vpc,
                   start_ip_idx,
                   private_route_tables,
                   private_security_group)

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
        (EnJapanConfiguration::vpc_net_mapping.map do |k,v|
          subs = IPAddress(v[:VPC]).subnet(24).drop(start_ip_idx).take(4).map(&:to_string)
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
          find_in_map('AWSRegionNetConfig', aws_region, "application#{z.upcase}"),
          availabilityZone: join('', aws_region, z),
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
          find_in_map('AWSRegionNetConfig', aws_region, "resource#{z.upcase}"),
          availabilityZone: join('', aws_region, z),
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

      security_group_vpc(
        'ApplicationSecurityGroup',
        'Security group of the application servers',
        vpc,
        tags: {
          'Name' => join('-', aws_stack_name, 'app', 'sg'),
          'Application' => aws_stack_name
        }
      )

    end

  end
end
