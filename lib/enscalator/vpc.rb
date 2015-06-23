# -*- encoding : utf-8 -*-

module Enscalator

  module Templates

    # Amazon AWS Virtual Private Cloud template
    class VPC < Enscalator::RichTemplateDSL

      def tpl

        value :Description => [
                'AWS CloudFormation for en-japan vpc: template creating en japan environment in a VPC.',
                'The stack contains 2 subnets: the first subnet is public and contains the',
                'load balancer, a NAT device for internet access from the private subnet and a',
                'bastion host to allow SSH access to the Elastic Beanstalk hosts.',
                'The second subnet is private and contains the Elastic Beanstalk instances.',
                'You will be billed for the AWS resources used if you create a stack from this template.'].join(' ')

        parameter 'NatKeyName',
                  :Description => 'Name of an existing EC2 KeyPair to enable SSH access to the nat host',
                  :Type => 'String',
                  :MinLength => '1',
                  :MaxLength => '64',
                  :AllowedPattern => '[-_ a-zA-Z0-9]*',
                  :ConstraintDescription => 'can contain only alphanumeric characters, spaces, dashes and underscores.'

        parameter_instance_type 'NAT', default: 't2.small'

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

        mapping 'AWSRegionNetConfig',
                Enscalator::EnJapanConfiguration::mapping_vpc_net

        mapping 'AWSRegion2AZ',
                Enscalator::EnJapanConfiguration::mapping_availability_zones

        resource 'VPC', :Type => 'AWS::EC2::VPC',
                 :Properties => {
                   :CidrBlock => find_in_map('AWSRegionNetConfig', ref('AWS::Region'), 'VPC'),
                   :EnableDnsSupport => 'true',
                   :EnableDnsHostnames => 'true',
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Public'
                     },
                   ],
                 }

        resource 'PublicSubnet1',
                 :DependsOn => ['VPC'],
                 :Type => 'AWS::EC2::Subnet',
                 :Properties => {
                   :VpcId => ref('VPC'),
                   :AvailabilityZone => join('', ref('AWS::Region'), 'a'),
                   :CidrBlock => find_in_map('AWSRegionNetConfig', ref('AWS::Region'), 'Public1'),
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Public'
                     },
                   ],
                 }

        resource 'PublicSubnet2',
                 :DependsOn => ['VPC'],
                 :Type => 'AWS::EC2::Subnet',
                 :Properties => {
                   :VpcId => ref('VPC'),
                   :AvailabilityZone => join('', ref('AWS::Region'), 'c'),
                   :CidrBlock => find_in_map('AWSRegionNetConfig', ref('AWS::Region'), 'Public2'),
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Public'
                     },
                   ],
                 }

        resource 'InternetGateway',
                 :Type => 'AWS::EC2::InternetGateway',
                 :Properties => {
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Public'
                     },
                   ],
                 }

        resource 'GatewayToInternet',
                 :DependsOn => ['VPC', 'InternetGateway'],
                 :Type => 'AWS::EC2::VPCGatewayAttachment',
                 :Properties => {
                   :VpcId => ref('VPC'),
                   :InternetGatewayId => ref('InternetGateway'),
                 }

        resource 'PublicRouteTable',
                 :DependsOn => ['VPC'],
                 :Type => 'AWS::EC2::RouteTable',
                 :Properties => {
                   :VpcId => ref('VPC'),
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Public'
                     },
                   ],
                 }

        resource 'PublicRoute',
                 :DependsOn => ['PublicRouteTable', 'InternetGateway'],
                 :Type => 'AWS::EC2::Route',
                 :Properties => {
                   :RouteTableId => ref('PublicRouteTable'),
                   :DestinationCidrBlock => '0.0.0.0/0',
                   :GatewayId => ref('InternetGateway'),
                 }

        resource 'PublicSubnetRouteTableAssociation1',
                 :DependsOn => ['PublicSubnet1', 'PublicRouteTable'],
                 :Type => 'AWS::EC2::SubnetRouteTableAssociation',
                 :Properties => {
                   :SubnetId => ref('PublicSubnet1'),
                   :RouteTableId => ref('PublicRouteTable'),
                 }

        resource 'PublicSubnetRouteTableAssociation2',
                 :DependsOn => ['PublicSubnet2', 'PublicRouteTable'],
                 :Type => 'AWS::EC2::SubnetRouteTableAssociation',
                 :Properties => {
                   :SubnetId => ref('PublicSubnet2'),
                   :RouteTableId => ref('PublicRouteTable'),
                 }

        resource 'PublicNetworkAcl',
                 :DependsOn => ['VPC'],
                 :Type => 'AWS::EC2::NetworkAcl',
                 :Properties => {
                   :VpcId => ref('VPC'),
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Public'
                     },
                   ],
                 }

        resource 'InboundHTTPPublicNetworkAclEntry',
                 :DependsOn => ['PublicNetworkAcl'],
                 :Type => 'AWS::EC2::NetworkAclEntry',
                 :Properties => {
                   :NetworkAclId => ref('PublicNetworkAcl'),
                   :RuleNumber => '100',
                   :Protocol => '-1',
                   :RuleAction => 'allow',
                   :Egress => 'false',
                   :CidrBlock => '0.0.0.0/0',
                   :PortRange => {:From => '0', :To => '65535'},
                 }

        resource 'OutboundHTTPPublicNetworkAclEntry',
                 :DependsOn => ['PublicNetworkAcl'],
                 :Type => 'AWS::EC2::NetworkAclEntry',
                 :Properties => {
                   :NetworkAclId => ref('PublicNetworkAcl'),
                   :RuleNumber => '100',
                   :Protocol => '-1',
                   :RuleAction => 'allow',
                   :Egress => 'true',
                   :CidrBlock => '0.0.0.0/0',
                   :PortRange => {:From => '0', :To => '65535'},
                 }

        resource 'PublicSubnetNetworkAclAssociation1',
                 :DependsOn => ['PublicSubnet1', 'PublicNetworkAcl'],
                 :Type => 'AWS::EC2::SubnetNetworkAclAssociation',
                 :Properties => {
                   :SubnetId => ref('PublicSubnet1'),
                   :NetworkAclId => ref('PublicNetworkAcl'),
                 }

        resource 'PublicSubnetNetworkAclAssociation2',
                 :DependsOn => ['PublicSubnet2', 'PublicNetworkAcl'],
                 :Type => 'AWS::EC2::SubnetNetworkAclAssociation',
                 :Properties => {
                   :SubnetId => ref('PublicSubnet2'),
                   :NetworkAclId => ref('PublicNetworkAcl'),
                 }

        resource 'PrivateRouteTable1',
                 :DependsOn => ['VPC'],
                 :Type => 'AWS::EC2::RouteTable',
                 :Properties => {
                   :VpcId => ref('VPC'),
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Private'
                     },
                   ],
                 }

        resource 'PrivateRouteTable2',
                 :DependsOn => ['VPC'],
                 :Type => 'AWS::EC2::RouteTable',
                 :Properties => {
                   :VpcId => ref('VPC'),
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Private'
                     },
                   ],
                 }

        resource 'PrivateRoute1',
                 :DependsOn => ['PrivateRouteTable1', 'NATDevice1'],
                 :Type => 'AWS::EC2::Route',
                 :Properties => {
                   :RouteTableId => ref('PrivateRouteTable1'),
                   :DestinationCidrBlock => '0.0.0.0/0',
                   :InstanceId => ref('NATDevice1'),
                 }

        resource 'PrivateRoute2',
                 :DependsOn => ['PrivateRouteTable2', 'NATDevice2'],
                 :Type => 'AWS::EC2::Route',
                 :Properties => {
                   :RouteTableId => ref('PrivateRouteTable2'),
                   :DestinationCidrBlock => '0.0.0.0/0',
                   :InstanceId => ref('NATDevice2'),
                 }

        resource 'PrivateNetworkAcl',
                 :DependsOn => ['VPC'],
                 :Type => 'AWS::EC2::NetworkAcl',
                 :Properties => {
                   :VpcId => ref('VPC'),
                   :Tags => [
                     {
                       :Key => 'Application',
                       :Value => aws_stack_name,
                     },
                     {
                       :Key => 'Network',
                       :Value => 'Private'
                     },
                   ],
                 }

        resource 'InboundPrivateNetworkAclEntry',
                 :DependsOn => ['PrivateNetworkAcl'],
                 :Type => 'AWS::EC2::NetworkAclEntry',
                 :Properties => {
                   :NetworkAclId => ref('PrivateNetworkAcl'),
                   :RuleNumber => '100',
                   :Protocol => '6',
                   :RuleAction => 'allow',
                   :Egress => 'false',
                   :CidrBlock => '0.0.0.0/0',
                   :PortRange => {:From => '0', :To => '65535'},
                 }

        resource 'OutBoundPrivateNetworkAclEntry',
                 :DependsOn => ['PrivateNetworkAcl'],
                 :Type => 'AWS::EC2::NetworkAclEntry',
                 :Properties => {
                   :NetworkAclId => ref('PrivateNetworkAcl'),
                   :RuleNumber => '100',
                   :Protocol => '6',
                   :RuleAction => 'allow',
                   :Egress => 'true',
                   :CidrBlock => '0.0.0.0/0',
                   :PortRange => {:From => '0', :To => '65535'},
                 }

        resource 'NATDevice1',
                 :DependsOn => ['PublicSubnet1', 'NATSecurityGroup'],
                 :Type => 'AWS::EC2::Instance',
                 :Properties => {
                   :InstanceType => ref('NATInstanceType'),
                   :KeyName => ref('NatKeyName'),
                   :SourceDestCheck => 'false',
                   :ImageId => find_in_map('AWSNATAMI', ref('AWS::Region'), 'AMI'),
                   :NetworkInterfaces => [
                     {
                       :AssociatePublicIpAddress => 'true',
                       :DeviceIndex => '0',
                       :SubnetId => ref('PublicSubnet1'),
                       :GroupSet => [ref('NATSecurityGroup')],
                     },
                   ],
                   :Tags => [
                     {
                       :Key => 'Name',
                       :Value => 'NATDevice1'
                     },
                   ],
                 }

        resource 'NATDevice2',
                 :DependsOn => ['PublicSubnet2', 'NATSecurityGroup'],
                 :Type => 'AWS::EC2::Instance',
                 :Properties => {
                   :InstanceType => ref('NATInstanceType'),
                   :SourceDestCheck => 'false',
                   :KeyName => ref('NatKeyName'),
                   :ImageId => find_in_map('AWSNATAMI', ref('AWS::Region'), 'AMI'),
                   :NetworkInterfaces => [
                     {
                       :AssociatePublicIpAddress => 'true',
                       :DeviceIndex => '0',
                       :SubnetId => ref('PublicSubnet2'),
                       :GroupSet => [ref('NATSecurityGroup')],
                     },
                   ],
                   :Tags => [
                     {
                       :Key => 'Name',
                       :Value => 'NATDevice2'
                     },
                   ],
                 }

        resource 'NATSecurityGroup',
                 :DependsOn => ['PrivateSecurityGroup'],
                 :Type => 'AWS::EC2::SecurityGroup',
                 :Properties => {
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
                     {
                       :IpProtocol => 'tcp',
                       :FromPort => '0',
                       :ToPort => '65535',
                       :CidrIp => '0.0.0.0/0'
                     }
                   ],
                 }

        resource 'PrivateSecurityGroup',
                 :DependsOn => ['VPC'],
                 :Type => 'AWS::EC2::SecurityGroup',
                 :Properties => {
                   :GroupDescription => 'Allow the Application instances to access the NAT device',
                   :VpcId => ref('VPC'),
                   :SecurityGroupEgress => [
                     {
                       :IpProtocol => 'tcp',
                       :FromPort => '0',
                       :ToPort => '65535',
                       :CidrIp => '10.0.0.0/8'
                     },
                   ],
                   :SecurityGroupIngress => [
                     {
                       :IpProtocol => 'tcp',
                       :FromPort => '0',
                       :ToPort => '65535',
                       :CidrIp => '10.0.0.0/8'
                     },
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

        output 'PrivateSecurityGroup',
               :Description => 'SecurityGroup to add private resources',
               :Value => ref('PrivateSecurityGroup')
      end # tpl
    end # EnJapanVPC
  end
end
