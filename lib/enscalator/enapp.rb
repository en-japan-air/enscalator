require 'cloudformation-ruby-dsl/cfntemplate'
require_relative 'richtemplate'

def en_app(vpc,
           private_route_tables,
           private_security_group,
           &block)
  Enscalator::EnAppTemplateDSL.new(
    vpc,
    start_ip,
    private_route_tables,
    private_security_group,
    &block)
end

module Enscalator

  class EnAppTemplateDSL < RichTemplateDSL

    def initialize(vpc,
                   private_route_tables,
                   private_security_group,
                   &block)

      super(&block)
      create_app(vpc,private_route_tables,private_security_group)

    end

    def create_app(
      vpc,
      private_route_tables,
      private_security_group)

      zones = ['a','c']

      parameter 'PrivateSecurityGroup',
        :Description => 'Security group identifier of private instances',
        :Default => private_security_group,
        :Type => 'String',
        :AllowedPattern => 'sg-[a-zA-Z0-9]*',
        :ConstraintDescription => 'must begin with sg- followed by numbers and alphanumeric characters.'


      private_route_tables.map do |z,table|
        parameter 'PrivateRouteTable'+z,
          :Description => 'Route table identifier for private instances of zone ' +z,
          :Default => table,
          :Type => 'String',
          :AllowedPattern => 'rtb-[a-zA-Z0-9]*',
          :ConstraintDescription => 'must begin with rtb- followed by numbers and alphanumeric characters.'
      end

      mapping 'AWSRegionNetConfig',
        :'us-east-1' => {
        :applicationa => 'test1',
        :applicationc => 'test1',
        :resourcea => 'test1',
        :resourcec => 'test1',
      },
      :us_west_1 => {
        :applicationa => 'test1',
        :applicationc => 'test1',
        :resourcea => 'test1',
        :resourcec => 'test1',
      }

      zones.map do |z|
        subnet(
          'ApplicationSubnet'+z,
          vpc,
          find_in_map('AWSRegionNetConfig', aws_region, 'application'+z),
          availabilityZone: join('', aws_region, z),
          tags:{
          'Network' => 'Private',
          'Application' => aws_stack_name,
          'immutable_metadata' => join('','{ "purpose": "', aws_stack_name, '-app" }')
        }
        )
      end

      zones.map do |z|
        subnet(
          'ResourceSubnet'+z,
          vpc,
          find_in_map('AWSRegionNetConfig', aws_region, 'resource'+z),
          availabilityZone: join('', aws_region, z),
          tags:{
          'Network' => 'Private',
          'Application' => aws_stack_name
        }
        )
      end

      zones.map do |z|
        resource 'RouteTableAssociation'+z, :Type => 'AWS::EC2::SubnetRouteTableAssociation', :Properties => {
          :RouteTableId => ref('PrivateRouteTable'+z),
          :SubnetId => ref('ApplicationSubnet'+z),
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
