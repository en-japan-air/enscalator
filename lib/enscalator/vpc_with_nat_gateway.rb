module Enscalator
  module Templates
    # Amazon AWS Virtual Private Cloud template with NAT gateway
    class VPCWithNATGateway < Enscalator::RichTemplateDSL
      include Enscalator::Plugins::NATGateway

      # Subnet size (256 addresses)
      SUBNET_CIDR_BLOCK_SIZE = 24

      # Template method
      def tpl
        description = <<-EOS.gsub(/^\s+\|/, '')
          |AWS CloudFormation template for the VPC environment.
          |For each availability zone stack creates: the public subnet, internet and NAT gateways,
          |internet access from private subnets, routing configuration for corresponding subnets
          |and security groups.
        EOS

        value Description: description

        mapping 'AWSRegionNetConfig', Core::NetworkConfig.mapping_vpc_net

        resource 'VPC',
                 Type: 'AWS::EC2::VPC',
                 Properties: {
                   CidrBlock: find_in_map('AWSRegionNetConfig', ref('AWS::Region'), 'VPC'),
                   EnableDnsSupport: 'true',
                   EnableDnsHostnames: 'true',
                   Tags: [
                     {
                       Key: 'Name',
                       Value: aws_stack_name
                     },
                     {
                       Key: 'Application',
                       Value: aws_stack_name
                     },
                     {
                       Key: 'Network',
                       Value: 'Public'
                     }
                   ]
                 }

        resource 'InternetGateway',
                 Type: 'AWS::EC2::InternetGateway',
                 Properties: {
                   Tags: [
                     {
                       Key: 'Name',
                       Value: 'Public Gateway'
                     },
                     {
                       Key: 'Application',
                       Value: aws_stack_name
                     },
                     {
                       Key: 'Network',
                       Value: 'Public'
                     }
                   ]
                 }

        resource 'GatewayToInternet',
                 DependsOn: %w( VPC InternetGateway ),
                 Type: 'AWS::EC2::VPCGatewayAttachment',
                 Properties: {
                   VpcId: ref('VPC'),
                   InternetGatewayId: ref('InternetGateway')
                 }

        resource 'PublicRouteTable',
                 DependsOn: ['VPC'],
                 Type: 'AWS::EC2::RouteTable',
                 Properties: {
                   VpcId: ref('VPC'),
                   Tags: [
                     {
                       Key: 'Name',
                       Value: 'Public'
                     },
                     {
                       Key: 'Application',
                       Value: aws_stack_name
                     },
                     {
                       Key: 'Network',
                       Value: 'Public'
                     }
                   ]
                 }

        resource 'PublicRoute',
                 DependsOn: %w( PublicRouteTable InternetGateway ),
                 Type: 'AWS::EC2::Route',
                 Properties: {
                   RouteTableId: ref('PublicRouteTable'),
                   DestinationCidrBlock: '0.0.0.0/0',
                   GatewayId: ref('InternetGateway')
                 }

        resource 'PublicNetworkAcl',
                 DependsOn: ['VPC'],
                 Type: 'AWS::EC2::NetworkAcl',
                 Properties: {
                   VpcId: ref('VPC'),
                   Tags: [
                     {
                       Key: 'Name',
                       Value: 'Public'
                     },
                     {
                       Key: 'Application',
                       Value: aws_stack_name
                     },
                     {
                       Key: 'Network',
                       Value: 'Public'
                     }
                   ]
                 }

        resource 'InboundHTTPPublicNetworkAclEntry',
                 DependsOn: ['PublicNetworkAcl'],
                 Type: 'AWS::EC2::NetworkAclEntry',
                 Properties: {
                   NetworkAclId: ref('PublicNetworkAcl'),
                   RuleNumber: '100',
                   Protocol: '-1',
                   RuleAction: 'allow',
                   Egress: 'false',
                   CidrBlock: '0.0.0.0/0',
                   PortRange: { From: '0', To: '65535' }
                 }

        resource 'OutboundHTTPPublicNetworkAclEntry',
                 DependsOn: ['PublicNetworkAcl'],
                 Type: 'AWS::EC2::NetworkAclEntry',
                 Properties: {
                   NetworkAclId: ref('PublicNetworkAcl'),
                   RuleNumber: '100',
                   Protocol: '-1',
                   RuleAction: 'allow',
                   Egress: 'true',
                   CidrBlock: '0.0.0.0/0',
                   PortRange: { From: '0', To: '65535' }
                 }

        resource 'PrivateNetworkAcl',
                 DependsOn: ['VPC'],
                 Type: 'AWS::EC2::NetworkAcl',
                 Properties: {
                   VpcId: ref('VPC'),
                   Tags: [
                     {
                       Key: 'Name',
                       Value: 'Private'
                     },
                     {
                       Key: 'Application',
                       Value: aws_stack_name
                     },
                     {
                       Key: 'Network',
                       Value: 'Private'
                     }
                   ]
                 }

        resource 'InboundPrivateNetworkAclEntry',
                 DependsOn: ['PrivateNetworkAcl'],
                 Type: 'AWS::EC2::NetworkAclEntry',
                 Properties: {
                   NetworkAclId: ref('PrivateNetworkAcl'),
                   RuleNumber: '100',
                   Protocol: '6',
                   RuleAction: 'allow',
                   Egress: 'false',
                   CidrBlock: '0.0.0.0/0',
                   PortRange: { From: '0', To: '65535' }
                 }

        resource 'OutBoundPrivateNetworkAclEntry',
                 DependsOn: ['PrivateNetworkAcl'],
                 Type: 'AWS::EC2::NetworkAclEntry',
                 Properties: {
                   NetworkAclId: ref('PrivateNetworkAcl'),
                   RuleNumber: '100',
                   Protocol: '6',
                   RuleAction: 'allow',
                   Egress: 'true',
                   CidrBlock: '0.0.0.0/0',
                   PortRange: { From: '0', To: '65535' }
                 }

        resource 'PrivateSecurityGroup',
                 DependsOn: ['VPC'],
                 Type: 'AWS::EC2::SecurityGroup',
                 Properties: {
                   GroupDescription: 'Allow the Application instances to access the NAT device',
                   VpcId: ref('VPC'),
                   SecurityGroupEgress: [
                     {
                       IpProtocol: 'tcp',
                       FromPort: '0',
                       ToPort: '65535',
                       CidrIp: '10.0.0.0/8'
                     }
                   ],
                   SecurityGroupIngress: [
                     {
                       IpProtocol: 'tcp',
                       FromPort: '0',
                       ToPort: '65535',
                       CidrIp: '10.0.0.0/8'
                     }
                   ],
                   Tags: [
                     {
                       Key: 'Name',
                       Value: 'Private'
                     }
                   ]
                 }

        current_cidr_block = Core::NetworkConfig.mapping_vpc_net[region.to_sym][:VPC]
        public_cidr_blocks =
          IPAddress(current_cidr_block).subnet(SUBNET_CIDR_BLOCK_SIZE).map(&:to_string).first(availability_zones.size)

        availability_zones.zip(public_cidr_blocks).each do |pair, cidr_block|
          suffix = pair.first
          public_subnet_name = "PublicSubnet#{suffix.upcase}"
          resource public_subnet_name,
                   DependsOn: ['VPC'],
                   Type: 'AWS::EC2::Subnet',
                   Properties: {
                     VpcId: ref('VPC'),
                     AvailabilityZone: join('', ref('AWS::Region'), suffix.to_s),
                     CidrBlock: cidr_block,
                     Tags: [
                       {
                         Key: 'Name',
                         Value: "Public #{suffix.upcase}"
                       },
                       {
                         Key: 'Application',
                         Value: aws_stack_name
                       },
                       {
                         Key: 'Network',
                         Value: 'Public'
                       }
                     ]
                   }

          resource "PublicSubnetRouteTableAssociation#{suffix.upcase}",
                   DependsOn: [public_subnet_name, 'PublicRouteTable'],
                   Type: 'AWS::EC2::SubnetRouteTableAssociation',
                   Properties: {
                     SubnetId: ref(public_subnet_name),
                     RouteTableId: ref('PublicRouteTable')
                   }

          private_route_table_name = "PrivateRouteTable#{suffix.upcase}"
          resource private_route_table_name,
                   DependsOn: ['VPC'],
                   Type: 'AWS::EC2::RouteTable',
                   Properties: {
                     VpcId: ref('VPC'),
                     Tags: [
                       {
                         Key: 'Name',
                         Value: "Private #{suffix.upcase}"
                       },
                       {
                         Key: 'Application',
                         Value: aws_stack_name
                       },
                       {
                         Key: 'Network',
                         Value: 'Private'
                       }
                     ]
                   }

          # Important!
          # When updating stack that was previously deployed using VPC template with NAT EC2 instance:
          # 1. Comment out lines related to NAT device below
          # 2. Update stack using this template (it will remove NAT instances and related security and routing rules)
          # 3. Revert changes from 1. (i.e. uncomment lines below)
          # 4. Update stack again (this time it will create new NAT Gateway, EIP and routing rule resources)
          nat_device_name = "NATDevice#{suffix.upcase}"
          nat_gateway_init(nat_device_name, public_subnet_name, private_route_table_name,
                           depends_on: [public_subnet_name, 'PublicRouteTable', 'GatewayToInternet'])

          output public_subnet_name,
                 Description: "Created Subnet #{suffix.upcase}",
                 Value: ref(public_subnet_name)
        end # each availability zone

        output 'VpcId',
               Description: 'Created VPC',
               Value: ref('VPC')

        output 'PrivateSecurityGroup',
               Description: 'SecurityGroup to add private resources',
               Value: ref('PrivateSecurityGroup')
      end # def tpl
    end # class VPC
  end # module Templates
end # module Enscalator
