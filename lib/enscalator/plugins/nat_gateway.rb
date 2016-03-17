module Enscalator
  module Plugins
    # VPC NAT Gateway plugin
    module NATGateway
      # Create new elastic IP in given VPC template
      #
      # @param [String] name resource name
      # @param [String] depends_on list of resource names this resource depends on
      # @return [Hash] result of Fn::GetAtt function
      def self.create_eip(name, depends_on: [])
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

      # Create new NAT gateway
      def nat_gateway_init(name, subnet_id, depends_on: [])
        nat_gateway_eip = create_eip("#{name}EIP", depends_on)

        nat_gateway_res_name = name
        nat_gateway_options = {
          Type: 'AWS::EC2::NatGateway'
        }
        nat_gateway_options.merge(DependsOn: depends_on) if depends_on && !depends_on.empty?
        nat_gateway_options.merge(AllocationId: nat_gateway_eip)
        # TODO: add subnetid
        resource nat_gateway_res_name, nat_gateway_options
      end
    end
  end
end
