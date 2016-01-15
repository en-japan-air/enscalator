module Enscalator
  module Plugins
    # VPC Peering Connection Plugin
    module VPCPeeringConnection
      def self.parameter_vpc_id(name, description, id)
        parameter name,
                  Default: id,
                  Description: description,
                  Type: 'String',
                  AllowedPattern: 'vpc-[a-zA-Z0-9]*',
                  ConstraintDescription: 'must be valid VPC id (vpc-*).'
      end

      # Create new vpc peering connection
      #
      # @param [String] conn_name connection name
      # @param [String] vpc_id id of the vpc instance
      # @param [Array<String>] tags list of tags
      def vpc_peering_init(conn_name, vpc_id, peer_vpc_id, tags: [])

        parameter_vpc_id("#{conn_name}VpcId", 'VpcId from where connection gets created', vpc_id)
        parameter_vpc_id("#{conn_name}PeerVpcId", 'VpcId where peering connection should go', peer_vpc_id)

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
