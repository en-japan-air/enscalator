module Enscalator
  module Templates
    # Amazon AWS Virtual Private Cloud template
    class VPC < Enscalator::RichTemplateDSL
      include Enscalator::Helpers

      # Template method
      def tpl
        nat_key_name = gen_ssh_key_name 'vpc-nat',
                                        region,
                                        stack_name

        description = <<-EOS.gsub(/^\s+\|/, '')
          |AWS CloudFormation for en-japan vpc: template creating en japan environment in a VPC.
          |The stack contains for each availability zone: the public subnet, NAT device for
          |internet access from the private subnets, internet gateway, routing configuration for
          |corresponding subnets and security groups.
        EOS

        pre_run do
          create_ssh_key nat_key_name, region, force_create: false
        end

        value Description: description

        parameter_ec2_instance_type 'NAT', type: 'c4.large'

        mapping 'AWSNATAMI',
                'us-east-1': { AMI: 'ami-68115b02' },
                'us-west-1': { AMI: 'ami-ef1a718f' },
                'us-west-2': { AMI: 'ami-77a4b816' },
                'eu-west-1': { AMI: 'ami-c0993ab3' },
                'eu-central-1': { AMI: 'ami-0b322e67' },
                'ap-northeast-1': { AMI: 'ami-f885ae96' },
                'ap-southeast-1': { AMI: 'ami-e2fc3f81' },
                'ap-southeast-2': { AMI: 'ami-e3217a80' },
                'sa-east-1': { AMI: 'ami-8631b5ea' }

        mapping 'AWSRegionNetConfig', NetworkConfig.mapping_vpc_net

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

        resource 'NATSecurityGroup',
                 DependsOn: ['PrivateSecurityGroup'],
                 Type: 'AWS::EC2::SecurityGroup',
                 Properties: {
                   GroupDescription: 'Enable internal access to the NAT device',
                   VpcId: ref('VPC'),
                   SecurityGroupIngress: [
                     {
                       IpProtocol: 'tcp',
                       FromPort: '80',
                       ToPort: '80',
                       SourceSecurityGroupId: ref('PrivateSecurityGroup')
                     },
                     {
                       IpProtocol: 'tcp',
                       FromPort: '443',
                       ToPort: '443',
                       SourceSecurityGroupId: ref('PrivateSecurityGroup')
                     },
                     {
                       IpProtocol: 'tcp',
                       FromPort: '465',
                       ToPort: '465',
                       SourceSecurityGroupId: ref('PrivateSecurityGroup')
                     }
                   ],
                   SecurityGroupEgress: [
                     {
                       IpProtocol: '-1',
                       FromPort: '0',
                       ToPort: '65535',
                       CidrIp: '0.0.0.0/0'
                     }
                   ],
                   Tags: [
                     {
                       Key: 'Name',
                       Value: 'NAT'
                     }
                   ]
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

        current_cidr_block = NetworkConfig.mapping_vpc_net[region.to_sym][:VPC]
        public_cidr_blocks = IPAddress(current_cidr_block).subnet(24).map(&:to_string).first(availability_zones.size)

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

          nat_device_name = "NATDevice#{suffix.upcase}"
          resource nat_device_name,
                   DependsOn: [public_subnet_name, 'NATSecurityGroup'],
                   Type: 'AWS::EC2::Instance',
                   Properties: {
                     InstanceType: ref('NATInstanceType'),
                     KeyName: nat_key_name,
                     SourceDestCheck: 'false',
                     ImageId: find_in_map('AWSNATAMI', ref('AWS::Region'), 'AMI'),
                     NetworkInterfaces: [
                       {
                         AssociatePublicIpAddress: 'true',
                         DeviceIndex: '0',
                         SubnetId: ref(public_subnet_name),
                         GroupSet: [ref('NATSecurityGroup')]
                       }
                     ],
                     Tags: [
                       {
                         Key: 'Name',
                         Value: nat_device_name
                       }
                     ]
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

          resource "PrivateRoute#{suffix.upcase}",
                   DependsOn: [private_route_table_name, nat_device_name],
                   Type: 'AWS::EC2::Route',
                   Properties: {
                     RouteTableId: ref(private_route_table_name),
                     DestinationCidrBlock: '0.0.0.0/0',
                     InstanceId: ref(nat_device_name)
                   }

          output public_subnet_name,
                 Description: "Created Subnet #{suffix.upcase}",
                 Value: ref(public_subnet_name)
        end

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
