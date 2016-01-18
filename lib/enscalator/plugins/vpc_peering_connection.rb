module Enscalator
  module Plugins
    # VPC Peering Connection Plugin
    module VPCPeeringConnection
      # Template parameter for VPC ID
      #
      # @param [String] name parameter name
      # @param [String] description parameter description
      def parameter_vpc_id(name, description, default_value = nil)
        options = {
          Description: description,
          Type: 'String',
          AllowedPattern: 'vpc-[a-zA-Z0-9]*',
          ConstraintDescription: 'must be valid VPC id (vpc-*).'
        }
        options[:Default] = default_value if default_value && !default_value.nil?
        parameter name, options
      end

      # Create new vpc peering connection
      #
      # @param [String] conn_name connection name
      # @param [Array<String>] tags list of tags
      def vpc_peering_init(conn_name, tags: [])
        options = {}
        options[:Properties] = {
          VpcId: ref("#{conn_name}VpcId"),
          PeerVpcId: ref("#{conn_name}PeerVpcId")
        }

        # Set plugin tags
        options[:Properties][:Tags] = tags if tags && !tags.empty?

        resource conn_name,
                 {
                   Type: 'AWS::EC2::VPCPeeringConnection'
                 }.merge(options)
      end
    end # module VPCPeeringConnection
  end # module Plugins
end # module Enscalator
