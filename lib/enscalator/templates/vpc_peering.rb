module Enscalator
  module Templates
    # VPC Peering connection between two VPCs
    class VPCPeering < Enscalator::RichTemplateDSL
      include Enscalator::Plugins::VPCPeeringConnection

      # Retrieve local VPC configuration from provisioned stack
      # @return [Aws::CloudFormation::Stack]
      def local_vpc_stack
        @local_vpc_stack ||= cfn_resource(cfn_client(region)).stack(vpc_stack_name)
      end

      # Interface for VPC
      # @param [String] id logical id of VPC
      # @return [Aws::EC2::Vpc]
      def vpc(id: get_resource(local_vpc_stack, 'VPC'))
        Aws::EC2::Vpc.new(id: id, region: region)
      end

      # VPC Peering connection can be created only if
      #
      # - both VPCs has to be in the same region
      # - CIDR blocks in connected VPCs has be different
      #
      # Route tables has to be created in the following way:
      #
      # VPC Local's route table
      # 172.16.0.0/16	-> Local
      # 10.0.0.0/16	-> pcx-11112222
      #
      # VPC Remote's route table
      # 10.0.0.0/16	Local
      # 172.16.0.0/16	pcx-11112222
      def tpl
        connection_name = 'PrivateConnection'
        local_vpc_id_ref, remote_vpc_id_ref, remote_route_table_id_ref =
          %W(#{connection_name}VpcId #{connection_name}PeerVpcId #{connection_name}PeerRouteTable)

        def validate_params(*params)
          params.each do |param|
            fail "Unable to find required parameter #{param}" unless @parameters.key?(param)
          end
        rescue RuntimeError => e
          puts e
          exit 1
        end

        validate_params(*[remote_vpc_id_ref, remote_route_table_id_ref])

        local_vpc, remote_vpc = [vpc, vpc(id: @parameters[remote_vpc_id_ref])]
        remote_route_table_id = @parameters[remote_route_table_id_ref]

        description 'Stack to create peering connection between two VPCs'

        parameter_vpc_id(local_vpc_id_ref,
                         'VpcId from where connection gets created',
                         local_vpc.id)

        parameter_vpc_id(remote_vpc_id_ref,
                         'VpcId where peering connection should go',
                         remote_vpc.id)

        parameter remote_route_table_id_ref, {
          Description: 'Route table for remote VPC',
          Default: remote_route_table_id,
          Type: 'String',
          AllowedPattern: 'rtb-[a-zA-Z0-9]*',
          ConstraintDescription: 'must be valid Route Table Id (rtb-*).'
        }

        # Initialize Peering connection
        vpc_peering_init(connection_name,
                         tags: [
                           {
                             Key: 'Name',
                             Value: connection_name
                           }
                         ])

        def route_table_from_stack(stack, logical_id)
          res = stack.resource(logical_id)
          res.resource_type == 'AWS::EC2::RouteTable' ? res.physical_resource_id : nil
        end

        local_route_table_id = route_table_from_stack(local_vpc_stack, 'PublicRouteTable')

        # Route for local VPC
        resource 'VpcPeeringRouteLocalVPC',
                 Type: 'AWS::EC2::Route',
                 Properties: {
                   RouteTableId: local_route_table_id,
                   DestinationCidrBlock: remote_vpc.cidr_block,
                   VpcPeeringConnectionId: ref(connection_name)
                 }

        # Route for remote VPC
        resource 'VpcPeeringRouteRemoteVPC',
                 Type: 'AWS::EC2::Route',
                 Properties: {
                   RouteTableId: remote_route_table_id,
                   DestinationCidrBlock: local_vpc.cidr_block,
                   VpcPeeringConnectionId: ref(connection_name)
                 }
      end # tpl
    end # class VPCPeering
  end # module Plugins
end # module Enscalator
