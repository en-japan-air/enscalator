module Enscalator

  # Namespace for cloudformation templates
  module Templates

    # enJapan Amazon AWS virtual private cloud template
    class EnJapanVPC < Enscalator::RichTemplateDSL
      def tpl

        value :AWSTemplateFormatVersion => '2010-09-09'

        value :Description => 'AWS CloudFormation for en-japan vpc: template creating en japan environment in a VPC. The stack contains 2 subnets: the first subnet is public and contains the load balancer, a NAT device for internet access from the private subnet and a bastion host to allow SSH access to the Elastic Beanstalk hosts. The second subnet is private and contains the Elastic Beanstalk instances. You will be billed for the AWS resources used if you create a stack from this template.'

        parameter 'BastionKeyName',
          :Description => 'Name of an existing EC2 KeyPair to enable SSH access to the bastion host',
          :Type => 'String',
          :MinLength => '1',
          :MaxLength => '64',
          :AllowedPattern => '[-_ a-zA-Z0-9]*',
          :ConstraintDescription => 'can contain only alphanumeric characters, spaces, dashes and underscores.'

        parameter 'SSHFrom',
          :Description => 'Lockdown SSH access to the bastion host (default can be accessed from anywhere)',
          :Type => 'String',
          :MinLength => '9',
          :MaxLength => '18',
          :Default => '0.0.0.0/0',
          :AllowedPattern => '(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})',
          :ConstraintDescription => 'must be a valid CIDR range of the form x.x.x.x/x.'

        parameter 'BastionInstanceType',
          :Description => 'Bastion Host EC2 instance type',
          :Type => 'String',
          :Default => 'm1.small',
          :AllowedValues => %w(t1.micro m1.small m1.medium m1.large m1.xlarge m2.xlarge m2.2xlarge m2.4xlarge c1.medium c1.xlarge cc1.4xlarge cc2.8xlarge cg1.4xlarge),
          :ConstraintDescription => 'must be a valid EC2 instance type.'

        parameter 'NATInstanceType',
          :Description => 'NAT Device EC2 instance type',
          :Type => 'String',
          :Default => 'm1.small',
          :AllowedValues => %w(t1.micro m1.small m1.medium m1.large m1.xlarge m2.xlarge m2.2xlarge m2.4xlarge c1.medium c1.xlarge cc1.4xlarge cc2.8xlarge cg1.4xlarge),
          :ConstraintDescription => 'must be a valid EC2 instance type.'

        mapping 'AWSNATAMI',
          :'us-east-1' => { :AMI => 'ami-c6699baf' },
          :'us-west-2' => { :AMI => 'ami-52ff7262' },
          :'us-west-1' => { :AMI => 'ami-3bcc9e7e' },
          :'eu-west-1' => { :AMI => 'ami-0b5b6c7f' },
          :'ap-southeast-1' => { :AMI => 'ami-02eb9350' },
          :'ap-northeast-1' => { :AMI => 'ami-14d86d15' },
          :'sa-east-1' => { :AMI => 'ami-0439e619' }

        mapping 'AWSInstanceType2Arch',
          :'t1.micro' => { :Arch => '64' },
          :'m1.small' => { :Arch => '64' },
          :'m1.medium' => { :Arch => '64' },
          :'m1.large' => { :Arch => '64' },
          :'m1.xlarge' => { :Arch => '64' },
          :'m2.xlarge' => { :Arch => '64' },
          :'m2.2xlarge' => { :Arch => '64' },
          :'m2.4xlarge' => { :Arch => '64' },
          :'c1.medium' => { :Arch => '64' },
          :'c1.xlarge' => { :Arch => '64' },
          :'cc1.4xlarge' => { :Arch => '64Cluster' },
          :'cc2.8xlarge' => { :Arch => '64Cluster' },
          :'cg1.4xlarge' => { :Arch => '64GPU' }

        mapping 'AWSRegionArch2AMI',
          :'us-east-1' => { :'32' => 'ami-a0cd60c9', :'64' => 'ami-aecd60c7', :'64Cluster' => 'ami-a8cd60c1', :'64GPU' => 'ami-eccf6285' },
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
          :'eu-west-1' => { :'32' => 'ami-61555115', :'64' => 'ami-6d555119', :'64Cluster' => 'ami-67555113', :'64GPU' => 'NOT_YET_SUPPORTED' },
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

        mapping 'AWSRegion2AZ',
          Enscalator::EnJapanConfiguration::mapping_availability_zones

        resource 'VPC', :Type => 'AWS::EC2::VPC', :Properties => {
          :CidrBlock => find_in_map('AWSRegionNetConfig', ref('AWS::Region'), 'VPC'),
          :EnableDnsSupport => 'true',
          :EnableDnsHostnames => 'true',
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Public' },
          ],
        }

        resource 'PublicSubnet1', :DependsOn => [ 'VPC' ], :Type => 'AWS::EC2::Subnet', :Properties => {
          :VpcId => ref('VPC'),
          :AvailabilityZone => join('', ref('AWS::Region'), 'a'),
          :CidrBlock => find_in_map('AWSRegionNetConfig', ref('AWS::Region'), 'Public1'),
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Public' },
          ],
        }

        resource 'PublicSubnet2', :DependsOn => [ 'VPC' ], :Type => 'AWS::EC2::Subnet', :Properties => {
          :VpcId => ref('VPC'),
          :AvailabilityZone => join('', ref('AWS::Region'), 'c'),
          :CidrBlock => find_in_map('AWSRegionNetConfig', ref('AWS::Region'), 'Public2'),
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Public' },
          ],
        }

        resource 'InternetGateway', :Type => 'AWS::EC2::InternetGateway', :Properties => {
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Public' },
          ],
        }

        resource 'GatewayToInternet', :DependsOn => [ 'VPC', 'InternetGateway' ], :Type => 'AWS::EC2::VPCGatewayAttachment', :Properties => {
          :VpcId => ref('VPC'),
          :InternetGatewayId => ref('InternetGateway'),
        }

        resource 'PublicRouteTable', :DependsOn => [ 'VPC' ], :Type => 'AWS::EC2::RouteTable', :Properties => {
          :VpcId => ref('VPC'),
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Public' },
          ],
        }

        resource 'PublicRoute', :DependsOn => [ 'PublicRouteTable', 'InternetGateway' ], :Type => 'AWS::EC2::Route', :Properties => {
          :RouteTableId => ref('PublicRouteTable'),
          :DestinationCidrBlock => '0.0.0.0/0',
          :GatewayId => ref('InternetGateway'),
        }

        resource 'PublicSubnetRouteTableAssociation1', :DependsOn => [ 'PublicSubnet1', 'PublicRouteTable' ], :Type => 'AWS::EC2::SubnetRouteTableAssociation', :Properties => {
          :SubnetId => ref('PublicSubnet1'),
          :RouteTableId => ref('PublicRouteTable'),
        }

        resource 'PublicSubnetRouteTableAssociation2', :DependsOn => [ 'PublicSubnet2', 'PublicRouteTable' ], :Type => 'AWS::EC2::SubnetRouteTableAssociation', :Properties => {
          :SubnetId => ref('PublicSubnet2'),
          :RouteTableId => ref('PublicRouteTable'),
        }

        resource 'PublicNetworkAcl', :DependsOn => [ 'VPC' ], :Type => 'AWS::EC2::NetworkAcl', :Properties => {
          :VpcId => ref('VPC'),
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Public' },
          ],
        }

        resource 'InboundHTTPPublicNetworkAclEntry', :DependsOn => [ 'PublicNetworkAcl' ], :Type => 'AWS::EC2::NetworkAclEntry', :Properties => {
          :NetworkAclId => ref('PublicNetworkAcl'),
          :RuleNumber => '100',
          :Protocol => '6',
          :RuleAction => 'allow',
          :Egress => 'false',
          :CidrBlock => '0.0.0.0/0',
          :PortRange => { :From => '80', :To => '80' },
        }

        resource 'InboundHTTPSPublicNetworkAclEntry', :DependsOn => [ 'PublicNetworkAcl' ], :Type => 'AWS::EC2::NetworkAclEntry', :Properties => {
          :NetworkAclId => ref('PublicNetworkAcl'),
          :RuleNumber => '101',
          :Protocol => '6',
          :RuleAction => 'allow',
          :Egress => 'false',
          :CidrBlock => '0.0.0.0/0',
          :PortRange => { :From => '443', :To => '443' },
        }

        resource 'InboundSSHPublicNetworkAclEntry', :DependsOn => [ 'PublicNetworkAcl' ], :Type => 'AWS::EC2::NetworkAclEntry', :Properties => {
          :NetworkAclId => ref('PublicNetworkAcl'),
          :RuleNumber => '102',
          :Protocol => '6',
          :RuleAction => 'allow',
          :Egress => 'false',
          :CidrBlock => ref('SSHFrom'),
          :PortRange => { :From => '22', :To => '22' },
        }

        resource 'InboundEmphemeralPublicNetworkAclEntry', :DependsOn => [ 'PublicNetworkAcl' ], :Type => 'AWS::EC2::NetworkAclEntry', :Properties => {
          :NetworkAclId => ref('PublicNetworkAcl'),
          :RuleNumber => '103',
          :Protocol => '6',
          :RuleAction => 'allow',
          :Egress => 'false',
          :CidrBlock => '0.0.0.0/0',
          :PortRange => { :From => '1024', :To => '65535' },
        }

        resource 'OutboundPublicNetworkAclEntry', :DependsOn => [ 'PublicNetworkAcl' ], :Type => 'AWS::EC2::NetworkAclEntry', :Properties => {
          :NetworkAclId => ref('PublicNetworkAcl'),
          :RuleNumber => '100',
          :Protocol => '6',
          :RuleAction => 'allow',
          :Egress => 'true',
          :CidrBlock => '0.0.0.0/0',
          :PortRange => { :From => '0', :To => '65535' },
        }

        resource 'PublicSubnetNetworkAclAssociation1', :DependsOn => [ 'PublicSubnet1', 'PublicNetworkAcl' ], :Type => 'AWS::EC2::SubnetNetworkAclAssociation', :Properties => {
          :SubnetId => ref('PublicSubnet1'),
          :NetworkAclId => ref('PublicNetworkAcl'),
        }

        resource 'PublicSubnetNetworkAclAssociation2', :DependsOn => [ 'PublicSubnet2', 'PublicNetworkAcl' ], :Type => 'AWS::EC2::SubnetNetworkAclAssociation', :Properties => {
          :SubnetId => ref('PublicSubnet2'),
          :NetworkAclId => ref('PublicNetworkAcl'),
        }

        resource 'PrivateRouteTable1', :DependsOn => [ 'VPC' ], :Type => 'AWS::EC2::RouteTable', :Properties => {
          :VpcId => ref('VPC'),
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Private' },
          ],
        }

        resource 'PrivateRouteTable2', :DependsOn => [ 'VPC' ], :Type => 'AWS::EC2::RouteTable', :Properties => {
          :VpcId => ref('VPC'),
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Private' },
          ],
        }

        resource 'PrivateRoute1', :DependsOn => [ 'PrivateRouteTable1', 'NATDevice1' ], :Type => 'AWS::EC2::Route', :Properties => {
          :RouteTableId => ref('PrivateRouteTable1'),
          :DestinationCidrBlock => '0.0.0.0/0',
          :InstanceId => ref('NATDevice1'),
        }

        resource 'PrivateRoute2', :DependsOn => [ 'PrivateRouteTable2', 'NATDevice2' ], :Type => 'AWS::EC2::Route', :Properties => {
          :RouteTableId => ref('PrivateRouteTable2'),
          :DestinationCidrBlock => '0.0.0.0/0',
          :InstanceId => ref('NATDevice2'),
        }

        resource 'PrivateNetworkAcl', :DependsOn => [ 'VPC' ], :Type => 'AWS::EC2::NetworkAcl', :Properties => {
          :VpcId => ref('VPC'),
          :Tags => [
            {
              :Key => 'Application',
              :Value => aws_stack_name,
            },
            { :Key => 'Network', :Value => 'Private' },
          ],
        }

        resource 'InboundPrivateNetworkAclEntry', :DependsOn => [ 'PrivateNetworkAcl' ], :Type => 'AWS::EC2::NetworkAclEntry', :Properties => {
          :NetworkAclId => ref('PrivateNetworkAcl'),
          :RuleNumber => '100',
          :Protocol => '6',
          :RuleAction => 'allow',
          :Egress => 'false',
          :CidrBlock => '0.0.0.0/0',
          :PortRange => { :From => '0', :To => '65535' },
        }

        resource 'OutBoundPrivateNetworkAclEntry', :DependsOn => [ 'PrivateNetworkAcl' ], :Type => 'AWS::EC2::NetworkAclEntry', :Properties => {
          :NetworkAclId => ref('PrivateNetworkAcl'),
          :RuleNumber => '100',
          :Protocol => '6',
          :RuleAction => 'allow',
          :Egress => 'true',
          :CidrBlock => '0.0.0.0/0',
          :PortRange => { :From => '0', :To => '65535' },
        }

        resource 'NATDevice1', :DependsOn => [ 'PublicSubnet1', 'NATSecurityGroup' ], :Type => 'AWS::EC2::Instance', :Properties => {
          :InstanceType => ref('NATInstanceType'),
          :KeyName => ref('BastionKeyName'),
          :SourceDestCheck => 'false',
          :ImageId => find_in_map('AWSNATAMI', ref('AWS::Region'), 'AMI'),
          :NetworkInterfaces => [
            {
              :AssociatePublicIpAddress => 'true',
              :DeviceIndex => '0',
              :SubnetId => ref('PublicSubnet1'),
              :GroupSet => [ ref('NATSecurityGroup') ],
            },
          ],
          :Tags => [
            { :Key => 'Name', :Value => 'NATDevice1' },
          ],
        }

        resource 'NATDevice2', :DependsOn => [ 'PublicSubnet2', 'NATSecurityGroup' ], :Type => 'AWS::EC2::Instance', :Properties => {
          :InstanceType => ref('NATInstanceType'),
          :SourceDestCheck => 'false',
          :KeyName => ref('BastionKeyName'),
          :ImageId => find_in_map('AWSNATAMI', ref('AWS::Region'), 'AMI'),
          :NetworkInterfaces => [
            {
              :AssociatePublicIpAddress => 'true',
              :DeviceIndex => '0',
              :SubnetId => ref('PublicSubnet2'),
              :GroupSet => [ ref('NATSecurityGroup') ],
            },
          ],
          :Tags => [
            { :Key => 'Name', :Value => 'NATDevice2' },
          ],
        }

        resource 'NATSecurityGroup', :DependsOn => [ 'PrivateSecurityGroup' ], :Type => 'AWS::EC2::SecurityGroup', :Properties => {
          :GroupDescription => 'Enable internal access to the NAT device',
          :VpcId => ref('VPC'),
          :SecurityGroupIngress => [
            {
              :IpProtocol => 'tcp',
              :FromPort => '80',
              :ToPort => '80',
              :SourceSecurityGroupId => ref('PrivateSecurityGroup'),
            },
            {
              :IpProtocol => 'tcp',
              :FromPort => '443',
              :ToPort => '443',
              :SourceSecurityGroupId => ref('PrivateSecurityGroup'),
            },
          ],
          :SecurityGroupEgress => [
            { :IpProtocol => 'tcp', :FromPort => '80', :ToPort => '80', :CidrIp => '0.0.0.0/0' },
            { :IpProtocol => 'tcp', :FromPort => '443', :ToPort => '443', :CidrIp => '0.0.0.0/0' },
          ],
        }

        resource 'BastionIPAddress1', :Type => 'AWS::EC2::EIP', :Properties => { :Domain => 'vpc' }

        resource 'BastionIPAddress2', :Type => 'AWS::EC2::EIP', :Properties => { :Domain => 'vpc' }

        resource 'BastionSecurityGroup', :DependsOn => [ 'VPC', 'PrivateSecurityGroup' ], :Type => 'AWS::EC2::SecurityGroup', :Properties => {
          :GroupDescription => 'Enable access to the Bastion host',
          :VpcId => ref('VPC'),
          :SecurityGroupIngress => [
            {
              :IpProtocol => 'tcp',
              :FromPort => '22',
              :ToPort => '22',
              :CidrIp => ref('SSHFrom'),
            },
            { :IpProtocol => 'udp', :FromPort => '500', :ToPort => '500', :CidrIp => '0.0.0.0/0' },
            { :IpProtocol => 'udp', :FromPort => '4500', :ToPort => '4500', :CidrIp => '0.0.0.0/0' },
          ],
          :SecurityGroupEgress => [
            {
              :IpProtocol => 'tcp',
              :FromPort => '22',
              :ToPort => '22',
              :SourceSecurityGroupId => ref('PrivateSecurityGroup'),
            },
            { :IpProtocol => 'tcp', :FromPort => '80', :ToPort => '80', :CidrIp => '0.0.0.0/0' },
            { :IpProtocol => 'tcp', :FromPort => '443', :ToPort => '443', :CidrIp => '0.0.0.0/0' },
          ],
        }

        resource 'PrivateSecurityGroup', :DependsOn => [ 'VPC' ], :Type => 'AWS::EC2::SecurityGroup', :Properties => {
          :GroupDescription => 'Allow the Application instances to access the NAT device',
          :VpcId => ref('VPC'),
          :SecurityGroupEgress => [
            { :IpProtocol => 'tcp', :FromPort => '0', :ToPort => '65535', :CidrIp => '10.0.0.0/8' },
          ],
          :SecurityGroupIngress => [
            { :IpProtocol => 'tcp', :FromPort => '0', :ToPort => '65535', :CidrIp => '10.0.0.0/8' },
          ],
        }

        output 'VpcId',
          :Description => 'Created VPC',
          :Value => ref('VPC')

        output 'PublicSubnet1',
          :Description => 'Created Subnet1',
          :Value => ref('PublicSubnet1')

        output 'PublicSubnet2',
          :Description => 'Created Subnet2',
          :Value => ref('PublicSubnet2')

        output 'BastionSecurityGroup',
          :Description => 'SecurityGroup to add the VPN gateways',
          :Value => ref('BastionSecurityGroup')

        output 'PrivateSecurityGroup',
          :Description => 'SecurityGroup to add private resources',
          :Value => ref('PrivateSecurityGroup')

        output 'BastionIp1',
          :Description => 'IP Address of the first Bastion host',
          :Value => ref('BastionIPAddress1')

        output 'BastionIpAllocationId1',
          :Description => 'Allocation Id of the EIP Address for the first Bastion host',
          :Value => get_att('BastionIPAddress1', 'AllocationId')

        output 'BastionIp2',
          :Description => 'IP Address of the second Bastion host',
          :Value => ref('BastionIPAddress2')

        output 'BastionIpAllocationId2',
          :Description => 'Allocation Id of the EIP Address for the second Bastion host',
          :Value => get_att('BastionIPAddress2', 'AllocationId')
      end # tpl
    end # EnJapanVPC
  end
end
