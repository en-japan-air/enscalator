require 'cloudformation-ruby-dsl/cfntemplate'

# Create new rich template
def rich_template(&block)
  Enscalator::RichTemplateDSL.new(&block)
end

module Enscalator

  # DSL specific for enscalator
  class RichTemplateDSL < TemplateDSL

    include Enscalator::Helpers
    include Enscalator::Route53

    # Create new RichTemplateDSL instance
    #
    # @param [Hash] options command-line arguments
    def initialize(options={})
      @options = options

      block = Proc.new { tpl }
      super(&block)
    end

    # Helper method to provide accessor for `region`
    #
    # @return [String] region
    # (since there is an instance variable with same name, it will be modified in `super` initializer,
    # thus `attr_reader` is not available)
    def region
      @options[:region]
    end

    # Helper method to provide value accessor for `stack_name`
    #
    # @return [String] stack_name
    # (since there is an instance variable with same name, it will be modified in `super` initializer,
    # thus `attr_reader` is not available)
    def stack_name
      @options[:stack_name]
    end

    # Helper method to provide value accessor for `vpc_stack_name`
    #
    # @return [String] vpc_stack_name
    # @raise [RuntimeError] if vpc-stack-name was not given
    def vpc_stack_name
      @options[:vpc_stack_name] || fail('Requires vpc-stack-name')
    end

    # Helper method to provide value accessor for `parameters`
    #
    # @return [Hash] parameters as key-value pairs
    # (since there is an instance variable with same name, it will be modified in `super` initializer,
    # thus `attr_reader` is not available)
    def parameters
      (@options[:parameters] || '').split(';').map { |s| s.split '=' }.to_h
    end

    # Hosted zone accessor
    #
    # @return [String] hosted zone, and ensure ending with a '.'
    # @raise [RuntimeError] if hosted zone is accessed but it's not configured
    def hosted_zone
      @options[:hosted_zone] || fail('Hosted zone has to be configured')
      @options[:hosted_zone].ends_with?('.') ? @options[:hosted_zone] : @options[:hosted_zone] + '.'
    end

    # Availability zones accessor
    def availability_zones
      @availability_zones ||= ec2_client(region)
                                .describe_availability_zones
                                .availability_zones
                                .select { |az| az.state == 'available' }
                                .collect(&:zone_name)
                                .map { |n| [n.last.to_sym, n] }
                                .to_h
    end

    # Pre-run hook
    #
    # @param [Proc] block hook body
    def pre_run(&block)
      (@pre_run_blocks ||= []) << block if block_given?
    end

    # Post-run hook
    #
    # @param [Proc] block hook body
    def post_run(&block)
      (@post_run_blocks ||= []) << block if block_given?
    end

    # Convert tags to properties
    #
    # @param [Hash] tags collection of tags
    # @return [Array] list of properties
    def tags_to_properties(tags)
      tags.map { |k, v| {:Key => k, :Value => v} }
    end

    # Template description
    #
    # @param [String] desc template description
    def description(desc)
      value :Description => desc
    end

    # VPC resource
    #
    # @param [String] name of the vpc name
    # @param [String] cidr ip address block in CIDR notation (Classless Inter-Domain Routing)
    # @param [String] enableDnsSupport enable dns support
    # @param [String] enableDnsHostnames enable dns hostname
    # @param [Array] dependsOn list of resources this vpc needs
    # @param [Hash] tags tags
    def vpc(name, cidr, enableDnsSupport: nil, enableDnsHostnames: nil, dependsOn: [], tags: {})
      properties = {
        :CidrBlock => cidr,
      }
      properties[:EnableDnsSupport] = enableDnsSupport unless enableDnsSupport.nil?
      properties[:EnableDnsHostnames] = enableDnsHostnames unless enableDnsHostnames.nil?
      unless tags.include?('Name')
        tags['Name'] = join('-', aws_stack_name, name)
      end
      properties[:Tags] = tags_to_properties(tags)
      options = {
        :Type => 'AWS::EC2::VPC',
        :Properties => properties
      }
      options[:DependsOn] = dependsOn unless dependsOn.empty?
      resource name, options
    end

    # Subnet resource
    #
    # @param [String] name of the vpc name
    # @param [String] cidr ip address block in CIDR notation (Classless Inter-Domain Routing)
    # @param [String] availabilityZone where subnet gets created
    # @param [Array] dependsOn list of resources this vpc needs
    # @param [Hash] tags tags
    def subnet(name, vpc, cidr, availabilityZone: '', dependsOn: [], tags: {})
      properties = {
        :VpcId => vpc,
        :CidrBlock => cidr,
      }
      properties[:AvailabilityZone] = availabilityZone unless availabilityZone.empty?
      unless tags.include?('Name')
        tags['Name'] = join('-', aws_stack_name, name)
      end
      properties[:Tags] = tags_to_properties(tags)

      options = {
        :Type => 'AWS::EC2::Subnet',
        :Properties => properties
      }
      options[:DependsOn] = dependsOn unless dependsOn.empty?
      resource name, options
    end


    # Security group
    #
    # @param [String] name of the security group
    # @param [String] description of security group
    # @param [Array] securityGroupEgress list of outbound rules
    # @param [Array] securityGroupIngress list of inbound rules
    # @param [Array] dependsOn list of resources this vpc needs
    # @param [Hash] tags tags
    def security_group(name, description, securityGroupEgress: [], securityGroupIngress: [], dependsOn: [], tags: {})
      properties = {
        :GroupDescription => description
      }
      properties[:SecurityGroupIngress] = securityGroupIngress unless securityGroupIngress.empty?
      properties[:SecurityGroupEgress] = securityGroupEgress unless securityGroupEgress.empty?
      unless tags.include?('Name')
        tags['Name'] = join('-', aws_stack_name, name)
      end
      properties[:Tags] = tags_to_properties(tags)
      options = {
        :Type => 'AWS::EC2::SecurityGroup',
        :Properties => properties
      }
      options[:DependsOn] = dependsOn unless dependsOn.empty?
      resource name, options
    end

    # VPC Security group
    #
    # @param [String] name of the security group
    # @param [String] description of security group
    # @param [Array] securityGroupEgress list of outbound rules
    # @param [Array] securityGroupIngress list of inbound rules
    # @param [Array] dependsOn list of resources this vpc needs
    # @param [Hash] tags tags
    def security_group_vpc(name, description, vpc, securityGroupEgress: [], securityGroupIngress: [], dependsOn: [], tags: {})
      properties = {
        :VpcId => vpc,
        :GroupDescription => description
      }
      properties[:SecurityGroupIngress] = securityGroupIngress unless securityGroupIngress.empty?
      properties[:SecurityGroupEgress] = securityGroupEgress unless securityGroupEgress.empty?
      unless tags.include?('Name')
        tags['Name'] = join('-', aws_stack_name, name)
      end
      properties[:Tags] = tags_to_properties(tags)
      options = {
        :Type => 'AWS::EC2::SecurityGroup',
        :Properties => properties
      }
      options[:DependsOn] = dependsOn unless dependsOn.empty?
      resource name, options
    end

    # Network interface
    #
    # @param [String] device_index network interface device index
    # @param [Hash] options
    def network_interface(device_index, options: {})
      options[:DeviceIndex] = device_index
      options
    end

    # Resource
    #
    # @param [String] name of the resource
    # @param [Hash] options options
    def resource(name, options)
      super

      if options[:Type] && %w{AWS::EC2::Instance}.include?(options[:Type])
        output "#{name}PrivateIpAddress",
               :Description => "#{name} Private IP Address",
               :Value => get_att(name, 'PrivateIp')
      end
    end

    # Key name parameter
    #
    # @param [String] instance_name for which ssh key was created
    def parameter_key_name(instance_name)
      parameter "#{instance_name}KeyName",
                :Description => "Name of the #{instance_name} ssh key pair",
                :Type => 'String',
                :MinLength => '1',
                :MaxLength => '64',
                :AllowedPattern => '[a-zA-Z][-_a-zA-Z0-9]*',
                :ConstraintDescription => 'can contain only alphanumeric characters, dashes and underscores.'
    end

    # Name parameter
    #
    # @param [String] instance_name instance name
    # @param [String] default default name
    # @param [Integer] min_length minimum length
    # @param [Integer] max_length maximum length
    def parameter_name(instance_name, default: nil, min_length: 1, max_length: 64)
      parameter "#{instance_name}Name",
                :Default => default ? default.to_s : "#{instance_name}",
                :Description => "#{instance_name} name",
                :Type => 'String',
                :MinLength => min_length,
                :MaxLength => max_length,
                :AllowedPattern => '[a-zA-Z][a-zA-Z0-9]*',
                :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'
    end

    # Username parameter
    #
    # @param [String] instance_name instance name
    # @param [String] default default username
    # @param [Integer] min_length minimum length
    # @param [Integer] max_length maximum length
    def parameter_username(instance_name, default: 'root', min_length: 1, max_length: 16)
      parameter "#{instance_name}Username",
                :Default => default,
                :NoEcho => 'true',
                :Description => "Username for #{instance_name} access",
                :Type => 'String',
                :MinLength => min_length,
                :MaxLength => max_length,
                :AllowedPattern => '[a-zA-Z][a-zA-Z0-9]*',
                :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'
    end

    # Password parameter
    #
    # @param [String] instance_name instance name
    # @param [String] default default value
    # @param [Integer] min_length minimum length
    # @param [Integer] max_length maximum length
    def parameter_password(instance_name, default: 'password', min_length: 8, max_length: 41)
      parameter "#{instance_name}Password",
                :Default => default,
                :NoEcho => 'true',
                :Description => "Password for #{instance_name} access",
                :Type => 'String',
                :MinLength => min_length,
                :MaxLength => max_length,
                :AllowedPattern => '[a-zA-Z0-9]*',
                :ConstraintDescription => 'must contain only alphanumeric characters.'
    end

    # Allocated storage parameter
    #
    # @param [String] instance_name instance name
    # @param [String] default size of instance primary storage
    # @param [Integer] min minimal allowed value
    # @param [Integer] max maximum allowed value
    def parameter_allocated_storage(instance_name, default: 5, min: 5, max: 1024)
      parameter "#{instance_name}AllocatedStorage",
                :Default => default.to_s,
                :Description => "The size of the #{instance_name} (Gb)",
                :Type => 'Number',
                :MinValue => min.to_s,
                :MaxValue => max.to_s,
                :ConstraintDescription => "must be between #{min} and #{max}Gb."
    end

    # iam instance profile with full access policies to passed services
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
                       Action: ['sts:AssumeRole'],
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

    # TODO: under refactoring
    # Current generation instance types
    #
    # @return [Array] allowed instance types
    def instance_type
      %w(t2.micro t2.small t2.medium m4.large m4.xlarge m4.2xlarge m4.4xlarge
        m4.10xlarge m3.medium m3.large m3.xlarge m3.2xlarge c4.large c4.xlarge
        c4.2xlarge c4.4xlarge c4.8xlarge c3.large c3.xlarge c3.2xlarge c3.4xlarge
        c3.8xlarge r3.large r3.xlarge r3.2xlarge r3.4xlarge r3.8xlarge g2.2xlarge
        g2.8xlarge i2.xlarge i2.xlarge i2.4xlarge i2.8xlarge d2.xlarge d2.2xlarge
        d2.4xlarge d2.8xlarge)
    end

    # TODO: under refactoring
    # @deprecated Will be removed once Amazon fully stops supporting these instances
    # Previous generation instance types
    #
    # @return [Array] allowed instance types
    def instance_type_obsolete
      %w(t1.micro m1.small m1.medium m1.large m1.xlarge
        c1.medium c1.xlarge cc2.8xlarge cg1.4xlarge
        m2.xlarge m2.2xlarge m2.4xlarge
        cr1.8xlarge hi1.4xlarge hs1.8xlarge)
    end

    # TODO: under refactoring
    # Instance type parameter
    #
    # @param [String] instance_name instance name
    # @param [String] type instance type (default: t2.micro)
    # @param [Array] allowed_values list used to override built-in instance types
    def parameter_instance_type(instance_name, type: 't2.micro', allowed_values: [])

      # check overrides first, then stable instances, then obsolete and fail if none matched
      allowed = if allowed_values.any? && allowed_values.include?(type)
                  allowed_values
                elsif instance_type.include?(type)
                  instance_type
                elsif instance_type_obsolete.include?(type)
                  warn('Using obsolete instance types')
                  instance_type_obsolete
                else
                  fail("Found not supported instance type: #{type}")
                end

      parameter "#{instance_name}InstanceType",
                :Default => type,
                :Description => "The #{instance_name} instance type",
                :Type => 'String',
                :AllowedValues => allowed,
                :ConstraintDescription => 'must be valid EC2 instance type.'
    end

    # EC2 Instance type parameter
    #
    # @param [String] instance_name name of the instance
    # @param [String] type instance type
    def parameter_ec2_instance_type(instance_name, type)
      ec2_inst = InstanceType.ec2_instance_type
    end

    # RDS Instance type parameter
    #
    # @param [String] instance_name name of the instance
    # @param [String] type instance type
    def parameter_rds_instance_type(instance_name, type)
      rds_inst = InstanceType.rds_instance_type
    end

    # @deprecated calling instance method directly is deprecated, use instance_vpc or instance_with_network instead
    # Create ec2 instance
    #
    # @param [String] name instance name
    # @param [String] image_id instance ami_id
    # @param [String] subnet instance subnet id
    # @param [String] security_groups instance security_groups (string of Security Groups IDs)
    # @param [Array] dependsOn resources necessary to be create prior to this instance
    # @param [Hash] properties other properties
    def instance(name, image_id, subnet, security_groups, dependsOn: [], properties: {})
      warn '[Deprecated] Use instance_vpc or instance_with_network instead'
      raise "Non VPC instance #{name} can not contain NetworkInterfaces" if properties.include?(:NetworkInterfaces)
      raise "Non VPC instance #{name} can not contain VPC SecurityGroups" if properties.include?(:SecurityGroupIds)
    end

    # Create ec2 instance in given vpc
    #
    # @param [String] name instance name
    # @param [String] image_id instance ami_id
    # @param [String] subnet instance subnet id
    # @param [String] security_groups instance security_groups (string of Security Groups IDs)
    # @param [Array] dependsOn resources necessary to be create prior to this instance
    # @param [Hash] properties other properties
    def instance_vpc(name, image_id, subnet, security_groups, dependsOn: [], properties: {})
      raise "VPC instance #{name} can not contain NetworkInterfaces and subnet or security_groups" if properties.include?(:NetworkInterfaces)
      raise "VPC instance #{name} can not contain non VPC SecurityGroups" if properties.include?(:SecurityGroups)
      properties[:ImageId] = image_id
      properties[:SubnetId] = subnet
      properties[:SecurityGroupIds] = security_groups
      if properties[:Tags] && !properties[:Tags].any? { |x| x[:Key] == 'Name' }
        properties[:Tags] << {:Key => 'Name', :Value => join('-', aws_stack_name, name)}
      end
      options = {
        :Type => 'AWS::EC2::Instance',
        :Properties => properties
      }

      options[:DependsOn] = dependsOn unless dependsOn.empty?
      resource name, options
    end

    # Create ec2 instance with attached to it network interface
    #
    # @param [String] name instance name
    # @param [String] image_id instance ami_id
    # @param [String] network_interfaces network interfaces
    # @param [Hash] properties other properties
    def instance_with_network(name, image_id, network_interfaces, properties: {})
      if ([:SubnetId, :SecurityGroups, :SecurityGroupIds] & properties).any?
        raise "Instance with NetworkInterfaces #{name} can not contain instance subnet or security_groups"
      else
        properties[:ImageId] = image_id
        properties[:NetworkInterfaces] = network_interfaces
        if properties[:Tags] && !properties[:Tags].any? { |x| x[:Key] == 'Name' }
          properties[:Tags] << {:Key => 'Name', :Value => join('-', aws_stack_name, name)}
        end
        options = {
          :Type => 'AWS::EC2::Instance',
          :Properties => properties
        }
        resource name, options
      end
    end

    # Dynamically define methods to access related parameters
    #
    # @param [String] name parameter key
    # @param [Hash] options options
    def parameter(name, options)
      default(:Parameters, {})[name] = options
      @parameters[name] ||= options[:Default]
      self.class.send(:define_method, :"ref_#{name.underscore}") do
        ref(name)
      end
    end

    # Adds block to the run queue
    #
    # @param [Array] items list of blocks
    def enqueue(items)
      (@run_queue ||= []).concat(items || [])
    end

    # Determine content of run queue and execute each block in queue in sequence
    def exec!
      enqueue(@pre_run_blocks) if @options[:pre_run]

      enqueue([@options[:expand] ? Proc.new { puts JSON.pretty_generate(self) } : Proc.new { cfn_cmd(self) }])

      enqueue(@post_run_blocks) if @options[:post_run]

      @run_queue.each(&:call) if @run_queue
    end

    # Run aws sdk cloud-formation command with stack configuration and parameters
    #
    # @param [RichTemplateDSL] template cloudformation template
    def cfn_cmd(template)

      command = %w{aws cloudformation}

      command << (@options[:create_stack] ? ' create-stack' : ' update-stack')

      if stack_name
        command.concat(%W{--stack-name '#{stack_name}'})
      end

      if region
        command.concat(%W{--region '#{region}'})
      end

      if @options[:capabilities]
        capabilities = @options[:capabilities]
        command.concat(%W{--capabilities '#{capabilities}'})
      end

      unless parameters.empty?
        params = parameters.map { |key, val| {:ParameterKey => key, :ParameterValue => val} }
        command.concat(%W{--parameters '#{params.to_json}'})
      end

      command.concat(%W{--template-body '#{template.to_json}'})

      run_cmd(command)
    end

  end
end
