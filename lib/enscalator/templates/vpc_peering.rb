module Enscalator
  module Templates
    # VPC Peering connection between two VPCs
    class VPCPeering < Enscalator::RichTemplateDSL
      include Enscalator::Plugins::VPCPeeringConnection

      # VPC Peering connection can be created only if
      #
      # - both VPC has to be in the same region
      # - CIDR blocks in connected VPC has be different
      def tpl
        # Get vpc configuration from already provisioned stack
        pre_run do
          @vpc ||= Aws::EC2::Vpc.new(id: get_resource(vpc_stack, 'VPC'), region: region)
        end

        # Initialize Peering connection

        # Create route rule

        # Associate new route rule with routing table

      end # tpl
    end # class VPCPeering
  end # module Plugins
end # module Enscalator
