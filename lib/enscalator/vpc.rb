module Enscalator
  module Templates
    # Amazon AWS Virtual Private Cloud template (defaults to template with NAT gateway)
    class VPC < Enscalator::Templates::VPCWithNATGateway
      # Call method with same name from superclass
      def tpl
        super
      end
    end # class VPC
  end # module Templates
end # module Enscalator
