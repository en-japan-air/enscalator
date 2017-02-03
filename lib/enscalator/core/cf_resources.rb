module Enscalator
  module Core
    # Resources for cloudformation template dsl
    module CfResources
      # VPC resource
      #
      # @param [String] name of the vpc name
      # @param [String] cidr ip address block in CIDR notation (Classless Inter-Domain Routing)
      # @param [String] enable_dns_support enable dns support
      # @param [String] enable_dns_hostnames enable dns hostname
      # @param [Array] depends_on list of resources this vpc needs
      # @param [Hash] tags tags
      def vpc(name, cidr, enable_dns_support: nil, enable_dns_hostnames: nil, depends_on: [], tags: {})
        properties = {
          CidrBlock: cidr
        }
        properties[:EnableDnsSupport] = enable_dns_support unless enable_dns_support.nil?
        properties[:EnableDnsHostnames] = enable_dns_hostnames unless enable_dns_hostnames.nil?
        unless tags.include?('Name')
          tags['Name'] = join('-', aws_stack_name, name)
        end
        properties[:Tags] = tags_to_properties(tags)
        options = {
          Type: 'AWS::EC2::VPC',
          Properties: properties
        }
        options[:DependsOn] = depends_on unless depends_on.empty?
        resource name, options
        name
      end

      # Subnet resource
      #
      # @param [String] name of the vpc name
      # @param [String] cidr ip address block in CIDR notation (Classless Inter-Domain Routing)
      # @param [String] availability_zone where subnet gets created
      # @param [Array] depends_on list of resources this vpc needs
      # @param [Hash] tags tags
      def subnet(name, vpc, cidr, availability_zone: '', depends_on: [], tags: {})
        properties = {
          VpcId: vpc,
          CidrBlock: cidr
        }
        properties[:AvailabilityZone] = availability_zone unless availability_zone.empty?
        unless tags.include?('Name')
          tags['Name'] = join('-', aws_stack_name, name)
        end
        properties[:Tags] = tags_to_properties(tags)

        options = {
          Type: 'AWS::EC2::Subnet',
          Properties: properties
        }
        options[:DependsOn] = depends_on unless depends_on.empty?
        resource name, options
        name
      end

      # Security group
      #
      # @param [String] name of the security group
      # @param [String] description of security group
      # @param [Array] security_group_egress list of outbound rules
      # @param [Array] security_group_ingress list of inbound rules
      # @param [Array] depends_on list of resources this vpc needs
      # @param [Hash] tags tags
      def security_group(name,
                         description,
                         security_group_egress: [],
                         security_group_ingress: [],
                         depends_on: [],
                         tags: {})
        properties = {
          GroupDescription: description
        }
        properties[:SecurityGroupEgress] = security_group_egress unless security_group_egress.empty?
        properties[:SecurityGroupIngress] = security_group_ingress unless security_group_ingress.empty?
        unless tags.include?('Name')
          tags['Name'] = join('-', aws_stack_name, name)
        end
        properties[:Tags] = tags_to_properties(tags)
        options = {
          Type: 'AWS::EC2::SecurityGroup',
          Properties: properties
        }
        options[:DependsOn] = depends_on unless depends_on.empty?
        resource name, options
        name
      end

      # VPC Security group
      #
      # @param [String] name of the security group
      # @param [String] description of security group
      # @param [Array] security_group_egress list of outbound rules
      # @param [Array] security_group_ingress list of inbound rules
      # @param [Array] depends_on list of resources this vpc needs
      # @param [Hash] tags tags
      def security_group_vpc(name,
                             description,
                             vpc,
                             security_group_egress: [],
                             security_group_ingress: [],
                             depends_on: [],
                             tags: {})
        properties = {
          VpcId: vpc,
          GroupDescription: description
        }
        properties[:SecurityGroupEgress] = security_group_egress unless security_group_egress.empty?
        properties[:SecurityGroupIngress] = security_group_ingress unless security_group_ingress.empty?
        unless tags.include?('Name')
          tags['Name'] = join('-', aws_stack_name, name)
        end
        properties[:Tags] = tags_to_properties(tags)
        options = {
          Type: 'AWS::EC2::SecurityGroup',
          Properties: properties
        }
        options[:DependsOn] = depends_on unless depends_on.empty?
        resource name, options
        name
      end

      # IAM instance profile with full access policies to passed services
      #
      # @param [String] role_name iam role name
      # @param [Array<String>] services a list of aws service name
      # @return [String] iam instance profile name
      def iam_instance_profile_with_full_access(role_name, *services)
        resource "#{role_name}Role",
                 Type: 'AWS::IAM::Role',
                 Properties: {
                   AssumeRolePolicyDocument: {
                     Statement: [
                       {
                         Effect: 'Allow',
                         Principal: {
                           Service: ['ec2.amazonaws.com']
                         },
                         Action: ['sts:AssumeRole']
                       }
                     ]
                   },
                   Path: '/',
                   Policies: [
                     {
                       PolicyName: "#{role_name}Policy",
                       PolicyDocument: {
                         Statement: services.map do |s|
                           {
                             Effect: 'Allow',
                             Action: "#{s}:*",
                             Resource: '*'
                           }
                         end
                       }
                     }
                   ]
                 }

        resource "#{role_name}InstanceProfile",
                 Type: 'AWS::IAM::InstanceProfile',
                 Properties: {
                   Path: '/',
                   Roles: [ref("#{role_name}Role")]
                 }

        ref("#{role_name}InstanceProfile")
      end

      # Create ec2 instance in given vpc
      #
      # @param [String] name instance name
      # @param [String] image_id instance ami_id
      # @param [String] subnet instance subnet id
      # @param [String] security_groups instance security_groups (string of Security Groups IDs)
      # @param [Array] depends_on resources necessary to be create prior to this instance
      # @param [Hash] properties other properties
      def instance_vpc(name, image_id, subnet, security_groups, depends_on: [], properties: {})
        fail "VPC instance #{name} can not contain non VPC SecurityGroups" if properties.include?(:SecurityGroups)
        if properties.include?(:NetworkInterfaces)
          fail "VPC instance #{name} can not contain NetworkInterfaces and subnet or security_groups"
        end
        properties[:ImageId] = image_id
        properties[:SubnetId] = subnet
        properties[:SecurityGroupIds] = security_groups
        if properties[:Tags] && !properties[:Tags].any? { |x| x[:Key] == 'Name' }
          properties[:Tags] << { Key: 'Name', Value: join('-', aws_stack_name, name) }
        end
        options = {
          Type: 'AWS::EC2::Instance',
          Properties: properties
        }

        options[:DependsOn] = depends_on unless depends_on.empty?
        resource name, options
        name
      end

      # Create ec2 instance with attached to it network interface
      #
      # @param [String] name instance name
      # @param [String] image_id instance ami_id
      # @param [String] network_interfaces network interfaces
      # @param [Hash] properties other properties
      def instance_with_network(name, image_id, network_interfaces, properties: {})
        if ([:SubnetId, :SecurityGroups, :SecurityGroupIds] & properties).any?
          fail "Instance with NetworkInterfaces #{name} can not contain instance subnet or security_groups"
        end
        properties[:ImageId] = image_id
        properties[:NetworkInterfaces] = network_interfaces
        if properties[:Tags] && !properties[:Tags].any? { |x| x[:Key] == 'Name' }
          properties[:Tags] << { Key: 'Name', Value: join('-', aws_stack_name, name) }
        end
        options = {
          Type: 'AWS::EC2::Instance',
          Properties: properties
        }
        resource name, options
        name
      end
    end
  end
end
