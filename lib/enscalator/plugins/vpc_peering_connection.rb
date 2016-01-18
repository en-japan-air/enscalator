module Enscalator
  module Plugins
    # VPC Peering Connection Plugin
    module VPCPeeringConnection

      # Template parameter for VPC ID
      #
      # @param [String] name parameter name
      # @param [String] description parameter description
      def parameter_vpc_id(name, description)
        parameter name,
                  Description: description,
                  Type: 'String',
                  AllowedPattern: 'vpc-[a-zA-Z0-9]*',
                  ConstraintDescription: 'must be valid VPC id (vpc-*).'
      end

      # Create new vpc peering connection
      #
      # @param [String] conn_name connection name
      # @param [Array<String>] tags list of tags
      def vpc_peering_init(conn_name, tags: [])
        parameter_vpc_id("#{conn_name}VpcId", 'VpcId from where connection gets created')
        parameter_vpc_id("#{conn_name}PeerVpcId", 'VpcId where peering connection should go')

        properties = {
          Type: 'AWS::EC2::VPCPeeringConnection',
          Properties: {
            VpcId: ref("#{conn_name}VpcId"),
            PeerVpcId: ref("#{conn_name}PeerVpcId")
          }
        }

        # Set plugin tags
        if properties.key?(:Tags) && !properties[:Tags].empty?
          properties[:Tags].concat(tags)
        else
          properties[:Tags] = tags
        end

        resource conn_name, properties
      end
    end # module VPCPeeringConnection
  end # module Plugins
end # module Enscalator
