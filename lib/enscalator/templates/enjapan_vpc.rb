module Enscalator

  module Templates

    # enJapan Amazon AWS virtual private cloud template
    class EnJapanVPC < Enscalator::RichTemplateDSL
      include Enscalator::Helpers

      def tpl

        nat_key_name = 'vpc-nat'

        pre_run { create_ssh_key nat_key_name, region, force_create: false }

        value :AWSTemplateFormatVersion => '2010-09-09'

        value :Description => [
                'AWS CloudFormation for en-japan vpc: template creating en japan environment in a VPC.',
                'The stack contains 2 subnets: the first subnet is public and contains the',
                'load balancer, a NAT device for internet access from the private subnet and a',
                'bastion host to allow SSH access to the Elastic Beanstalk hosts.',
                'The second subnet is private and contains the Elastic Beanstalk instances.',
                'You will be billed for the AWS resources used if you create a stack from this template.'].join(' ')

        parameter 'NATInstanceType',
                  :Description => 'NAT Device EC2 instance type',
                  :Type => 'String',
                  :Default => 't2.small',
                  :AllowedValues => %w(t2.micro t2.small t2.medium m4.large m4.xlarge m4.2xlarge m4.4xlarge
                                    m4.10xlarge m3.medium m3.large m3.xlarge m3.2xlarge c4.large c4.xlarge
                                    c4.2xlarge c4.4xlarge c4.8xlarge c3.large c3.xlarge c3.2xlarge c3.4xlarge
                                    c3.8xlarge r3.large r3.xlarge r3.2xlarge r3.4xlarge r3.8xlarge g2.2xlarge
                                    g2.8xlarge i2.xlarge i2.xlarge i2.4xlarge i2.8xlarge d2.xlarge d2.2xlarge
                                    d2.4xlarge d2.8xlarge),
                  :ConstraintDescription => 'must be a valid EC2 instance type.'

        mapping 'AWSNATAMI',
                :'us-east-1' => {:AMI => 'ami-303b1458'},
                :'us-west-1' => {:AMI => 'ami-7da94839'},
                :'us-west-2' => {:AMI => 'ami-69ae8259'},
                :'eu-west-1' => {:AMI => 'ami-6975eb1e'},
                :'eu-central-1' => {:AMI => 'ami-46073a5b'},
                :'ap-northeast-1' => {:AMI => 'ami-03cf3903'},
                :'ap-southeast-1' => {:AMI => 'ami-b49dace6'},
                :'ap-southeast-2' => {:AMI => 'ami-e7ee9edd'},
                :'sa-east-1' => {:AMI => 'ami-fbfa41e6'}

        mapping 'AWSInstanceType2Arch',
                :'t1.micro' => {:Arch => '64'},
                :'m1.small' => {:Arch => '64'},
                :'m1.medium' => {:Arch => '64'},
                :'m1.large' => {:Arch => '64'},
                :'m1.xlarge' => {:Arch => '64'},
                :'m2.xlarge' => {:Arch => '64'},
                :'m2.2xlarge' => {:Arch => '64'},
                :'m2.4xlarge' => {:Arch => '64'},
                :'c1.medium' => {:Arch => '64'},
                :'c1.xlarge' => {:Arch => '64'},
                :'cc1.4xlarge' => {:Arch => '64Cluster'},
                :'cc2.8xlarge' => {:Arch => '64Cluster'},
                :'cg1.4xlarge' => {:Arch => '64GPU'}

        mapping 'AWSRegionArch2AMI',
                :'us-east-1' => {
                  :'32' => 'ami-a0cd60c9',
                  :'64' => 'ami-aecd60c7',
                  :'64Cluster' => 'ami-a8cd60c1',
                  :'64GPU' => 'ami-eccf6285'
                },
                :'us-west-2' => {
                  :'32' => 'ami-46da5576',
                  :'64' => 'ami-48da5578',
                  :'64Cluster' => 'NOT_YET_SUPPORTED',
                  :'64GPU' => 'NOT_YET_SUPPORTED',
                },
                :'us-west-1' => {
                  :'32' => 'ami-7d4c6938',
                  :'64' => 'ami-734c6936',
                  :'64Cluster' => 'NOT_YET_SUPPORTED',
                  :'64GPU' => 'NOT_YET_SUPPORTED',
                },
                :'eu-west-1' => {
                  :'32' => 'ami-61555115',
                  :'64' => 'ami-6d555119',
                  :'64Cluster' => 'ami-67555113',
                  :'64GPU' => 'NOT_YET_SUPPORTED'
                },
                :'ap-southeast-1' => {
                  :'32' => 'ami-220b4a70',
                  :'64' => 'ami-3c0b4a6e',
                  :'64Cluster' => 'NOT_YET_SUPPORTED',
                  :'64GPU' => 'NOT_YET_SUPPORTED',
                },
                :'ap-northeast-1' => {
                  :'32' => 'ami-2a19aa2b',
                  :'64' => 'ami-2819aa29',
                  :'64Cluster' => 'NOT_YET_SUPPORTED',
                  :'64GPU' => 'NOT_YET_SUPPORTED',
                },
                :'sa-east-1' => {
                  :'32' => 'ami-f836e8e5',
                  :'64' => 'ami-fe36e8e3',
                  :'64Cluster' => 'NOT_YET_SUPPORTED',
                  :'64GPU' => 'NOT_YET_SUPPORTED',
                }

        mapping 'AWSRegionNetConfig',
                Enscalator::EnJapanConfiguration::mapping_vpc_net

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
                   InternetGatewayId: ref('InternetGateway'),
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
                   PortRange: {From: '0', To: '65535'}
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
                   PortRange: {From: '0', To: '65535'}
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
                   PortRange: {From: '0', To: '65535'}
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
                   PortRange: {From: '0', To: '65535'}
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
                       SourceSecurityGroupId: ref('PrivateSecurityGroup'),
                     },
                     {
                       IpProtocol: 'tcp',
                       FromPort: '443',
                       ToPort: '443',
                       SourceSecurityGroupId: ref('PrivateSecurityGroup'),
                     }
                   ],
                   SecurityGroupEgress: [
                     {
                       IpProtocol: 'tcp',
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

        public_cidr_blocks = IPAddress(EnJapanConfiguration.mapping_vpc_net[region.to_sym][:VPC])
                               .subnet(24)
                               .map(&:to_string)
                               .first(availability_zones.size)
        availability_zones.zip(public_cidr_blocks).each do |pair, cidr_block|
          suffix, _ = pair
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
                     RouteTableId: ref('PublicRouteTable'),
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
                         GroupSet: [ref('NATSecurityGroup')],
                       },
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
                         Value: "Private #{suffix.upcase}",
                       },
                       {
                         Key: 'Application',
                         Value: aws_stack_name,
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
                     InstanceId: ref(nat_device_name),
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
    end # class EnJapanVPC
  end # module Templates
end # module Enscalator
