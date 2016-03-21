module Enscalator
  module Plugins
    # VPC NAT Gateway plugin
    module NATGateway
      # Allocate new elastic IP in given VPC template
      #
      # @param [String] name eip resource name
      # @param [Array<String>] depends_on list of resource names this resource depends on
      # @return [Hash] result of Fn::GetAtt function
      def allocate_new_eip(name, depends_on: [])
        fail('Dependency on the VPC-gateway attachment must be provided') if depends_on.empty?
        eip_resource_name = name
        resource eip_resource_name,
                 DependsOn: depends_on,
                 Type: 'AWS::EC2::EIP',
                 Properties: {
                   Domain: 'vpc'
                 }
        get_att(eip_resource_name, 'AllocationId')
      end

      # Create new route rule
      #
      # @param [String] name route rule name
      # @param [Array<String>] depends_on list of resource names this resource depends on
      def add_route_rule(name, route_table_name, nat_gateway_name, dest_cidr_block, depends_on: [])
        options = {
          Type: 'AWS::EC2::Route'
        }
        options[:DependsOn] = depends_on if depends_on && !depends_on.empty?
        resource name,
                 options.merge(
                   Properties: {
                     RouteTableId: ref(route_table_name),
                     NatGatewayId: ref(nat_gateway_name),
                     DestinationCidrBlock: dest_cidr_block
                   })
      end

      # Create new NAT gateway
      def nat_gateway_init(name, subnet_name, route_table_name, dest_cidr_block: '0.0.0.0/0', depends_on: [])
        nat_gateway_eip_name = "#{name}EIP"
        nat_gateway_eip = allocate_new_eip(nat_gateway_eip_name, depends_on: depends_on)
        nat_gateway_name = name
        nat_gateway_options = {
          Type: 'AWS::EC2::NatGateway'
        }
        nat_gateway_options[:DependsOn] = depends_on if depends_on && !depends_on.empty?
        resource nat_gateway_name,
                 nat_gateway_options.merge(
                   Properties: {
                     AllocationId: nat_gateway_eip,
                     SubnetId: ref(subnet_name)
                   })
        nat_route_rule_name = "#{name}Route"
        add_route_rule(nat_route_rule_name, route_table_name, nat_gateway_name, dest_cidr_block, depends_on: depends_on)
        nat_gateway_name
      end
    end
  end
end
