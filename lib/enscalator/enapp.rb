require 'cloudformation-ruby-dsl/cfntemplate'
require_relative 'rich_template_dsl'

module Enscalator
  # Template DSL for common enJapan application stack
  class EnAppTemplateDSL < RichTemplateDSL
    include Enscalator::Helpers

    attr_reader :app_name

    Struct.new('Subnet', :availability_zone, :suffix, :cidr_block)

    # Subnet size (256 addresses)
    SUBNET_CIDR_BLOCK_SIZE = 24

    # Create new EnAppTemplateDSL instance
    #
    # @param [Hash] options command-line arguments
    def initialize(options = {})
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

    # Get current stack
    #
    # @return [Aws::CloudFormation::Stack] current stack
    def current_stack
      @current_stack ||= (cfn_resource(cfn_client(region)).stack(stack_name) rescue nil) unless creating?
    end

    # Get vpc
    #
    # @return [Aws::EC2::Vpc] vpc instance
    def vpc
      @vpc ||= Aws::EC2::Vpc.new(id: get_resource(vpc_stack, 'VPC'), region: region)
    end

    # References to application subnets in all availability zones
    def ref_application_subnets
      availability_zones.map { |suffix, _| ref("ApplicationSubnet#{suffix.upcase}") }
    end

    # References to resource subnets in all availability zones
    def ref_resource_subnets
      availability_zones.map { |suffix, _| ref("ResourceSubnet#{suffix.upcase}") }
    end

    # Public subnets in all availability zones
    def public_subnets
      availability_zones.map { |suffix, _| get_resource(vpc_stack, "PublicSubnet#{suffix.upcase}") }
    end

    # Get VPC ID as reference to parameter
    # @return [Hash]
    def ref_vpc_id
      ref('VpcId')
    end

    # Reference to private security group
    # @return [Hash]
    def ref_private_security_group
      ref('PrivateSecurityGroup')
    end

    # Reference to resource security group
    # @return [Hash]
    def ref_resource_security_group
      ref('ResourceSecurityGroup')
    end

    # Reference to application security group
    # @return [Hash]
    def ref_application_security_group
      ref('ApplicationSecurityGroup')
    end

    # Get all CIRD blocks for current VPC
    # @return [Hash]
    def get_all_cidr_blocks
      IPAddress(
        Core::NetworkConfig.mapping_vpc_net[region.to_sym][:VPC]).subnet(SUBNET_CIDR_BLOCK_SIZE).map(&:to_string)
    end

    # Get currently used CIDR blocks
    # @return [Array]
    def get_used_cidr_blocks
      vpc.subnets.collect(&:cidr_block)
    end

    # Get non-used CIDR blocks
    # @return [Array]
    def get_available_cidr_blocks
      get_all_cidr_blocks - get_used_cidr_blocks
    end

    # Get application CIDR blocks availability zones mapping
    # @return [Hash]
    def get_application_to_az_mapping
      cidr_blocks = get_available_cidr_blocks.dup
      availability_zones.map do |suffix, az|
        cidr_block = (begin
          subnet_id = get_resource(current_stack, "ApplicationSubnet#{suffix.upcase}")
          Aws::EC2::Subnet.new(id: subnet_id, region: region).cidr_block
        end rescue nil) if current_stack

        Struct::Subnet.new(az, suffix, cidr_block || cidr_blocks.shift)
      end
    end

    # CIDR blocks allocated for application subnets
    # @return [Array]
    def get_application_cidr_blocks
      get_application_to_az_mapping.map(&:cidr_block)
    end

    # Get resource CIDR blocks availability zones mapping
    # @return [Array]
    def get_resource_to_az_mapping
      cidr_blocks = (get_available_cidr_blocks - get_application_cidr_blocks).dup
      availability_zones.map do |suffix, az|
        cidr_block = (begin
          subnet_id = get_resource(current_stack, "ResourceSubnet#{suffix.upcase}")
          Aws::EC2::Subnet.new(id: subnet_id, region: region).cidr_block
        end rescue nil) if current_stack

        Struct::Subnet.new(az, suffix, cidr_block || cidr_blocks.shift)
      end
    end

    # CIDR blocks allocated for resource subnets
    # @return [Array]
    def get_resource_cidr_blocks
      get_resource_to_az_mapping.map(&:cidr_block)
    end

    # Query and pre-configure VPC parameters required for the stack
    def load_vpc_params
      parameter 'VpcId',
                Description: 'The Id of the VPC',
                Default: vpc.id,
                Type: 'String',
                AllowedPattern: 'vpc-[a-zA-Z0-9]*',
                ConstraintDescription: 'must begin with vpc- followed by numbers and alphanumeric characters.'

      parameter 'PrivateSecurityGroup',
                Description: 'Security group identifier of private instances',
                Default: get_resource(vpc_stack, 'PrivateSecurityGroup'),
                Type: 'String',
                AllowedPattern: 'sg-[a-zA-Z0-9]*',
                ConstraintDescription: 'must begin with sg- followed by numbers and alphanumeric characters.'

      # allocate application/resource cidr blocks dynamically for all availability zones
      availability_zones.zip(get_application_cidr_blocks,
                             get_resource_cidr_blocks).each do |pair, application_cidr_block, resource_cidr_block|
        suffix, availability_zone = pair

        private_route_table_name = "PrivateRouteTable#{suffix.upcase}"
        parameter private_route_table_name,
                  Description: "Route table identifier for private instances of zone #{suffix}",
                  Default: get_resource(vpc_stack, private_route_table_name),
                  Type: 'String',
                  AllowedPattern: 'rtb-[a-zA-Z0-9]*',
                  ConstraintDescription: 'must begin with rtb- followed by numbers and alphanumeric characters.'

        application_subnet_name = "ApplicationSubnet#{suffix.upcase}"
        subnet application_subnet_name,
               vpc.id,
               application_cidr_block,
               availability_zone: availability_zone,
               tags: {
                 Network: 'Private',
                 Application: aws_stack_name,
                 immutable_metadata: join('', '{ "purpose": "', aws_stack_name, '-app" }')
               }

        resource_subnet_name = "ResourceSubnet#{suffix.upcase}"
        subnet resource_subnet_name,
               vpc.id,
               resource_cidr_block,
               availability_zone: availability_zone,
               tags: {
                 Network: 'Private',
                 Application: aws_stack_name
               }

        resource "ApplicationRouteTableAssociation#{suffix.upcase}",
                 Type: 'AWS::EC2::SubnetRouteTableAssociation',
                 Properties: {
                   RouteTableId: ref(private_route_table_name),
                   SubnetId: ref(application_subnet_name)
                 }

        resource "ResourceRouteTableAssociation#{suffix.upcase}",
                 Type: 'AWS::EC2::SubnetRouteTableAssociation',
                 Properties: {
                   RouteTableId: ref(private_route_table_name),
                   SubnetId: ref(resource_subnet_name)
                 }
      end

      security_group_vpc 'ResourceSecurityGroup',
                         'Enable internal access with ssh',
                         vpc.id,
                         security_group_ingress: [
                           {
                             IpProtocol: 'tcp',
                             FromPort: '22',
                             ToPort: '22',
                             CidrIp: '10.0.0.0/8'
                           },
                           {
                             IpProtocol: 'tcp',
                             FromPort: '0',
                             ToPort: '65535',
                             SourceSecurityGroupId: ref_application_security_group
                           }
                         ],
                         tags: {
                           Name: join('-', aws_stack_name, 'res', 'sg'),
                           Application: aws_stack_name
                         }

      security_group_vpc 'ApplicationSecurityGroup',
                         'Security group of the application servers',
                         vpc.id,
                         security_group_ingress: [
                           {
                             IpProtocol: 'tcp',
                             FromPort: '0',
                             ToPort: '65535',
                             CidrIp: '10.0.0.0/8'
                           }
                         ],
                         tags: {
                           Name: join('-', aws_stack_name, 'app', 'sg'),
                           Application: aws_stack_name
                         }
    end
  end # class EnAppTemplateDSL
end # module Enscalator
