require 'cloudformation-ruby-dsl/cfntemplate'

def rich_template(&block)
  Enscalator::RichTemplateDSL.new(&block)
end

module Enscalator
  class RichTemplateDSL < TemplateDSL
    include Route53

    def initialize(options={}) 
      @options = options # Options contains the cli args 
      block = Proc.new { tpl } 
      super(&block) 
    end 

    # Pre-run hook
    #
    # @param block [Proc] hook body
    def pre_run(&block)
      (@pre_run_blocks ||= []) << block if block_given?
    end

    # Post-run hook
    #
    # @param block [Proc] hook body
    def post_run(&block)
      (@post_run_blocks ||= []) << block if block_given?
    end

    def tags_to_properties(tags)
      tags.map { |k,v| {:Key => k, :Value => v}}
    end

    # Template description
    #
    # @param desc [String] template description
    def description(desc)
      value :Description => desc
    end

    def vpc(name, cidr, enableDnsSupport:nil, enableDnsHostnames:nil, dependsOn:[], tags:{})
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


    def subnet(name, vpc, cidr, availabilityZone:'', dependsOn:[], tags:{})
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


    def security_group(name, description, securityGroupEgress:[], securityGroupIngress:[], dependsOn:[], tags:{})
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

    def security_group_vpc(name, description, vpc, securityGroupEgress:[], securityGroupIngress:[], dependsOn:[], tags:{})
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

    def network_interface(device_index, options:{})
      options[:DeviceIndex] = device_index
      options
    end

    def resource(name, options)
      super

      if options[:Type] && %w{AWS::EC2::Instance}.include?(options[:Type])
        output "#{name}PrivateIpAddress",
          :Description => "#{name} Private IP Address",
          :Value => get_att(name, 'PrivateIp')
      end
    end

    # Keyname parameter
    #
    # @param instance_name [String] instance name
    def parameter_keyname(instance_name)
      parameter "#{instance_name}KeyName",
        :Description => "Name of the #{instance_name} ssh key pair",
        :Type => 'String',
        :MinLength => '1',
        :MaxLength => '64',
        :AllowedPattern => '[a-zA-Z][a-zA-Z0-9]*',
        :ConstraintDescription => 'must begin with a letter and contain only alphanumeric characters.'
    end

    # Name parameter
    #
    # @param instance_name [String] instance name
    # @param default [String] default name
    # @param min_length [Integer] minimum length
    # @param max_length [Integer] maximum length
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
    # @param instance_name [String] instance name
    # @param default [String] default username
    # @param min_length [Integer] minimum length
    # @param max_length [Integer] maximum length
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
    # @param instance_name [String] instance name
    # @param default [String] default value
    # @param min_length [Integer] minimum length
    # @param max_length [Integer] maximum length
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
    # @param instance_name [String] instance name
    # @param default [String] default size of instance primary storage
    # @param min [Integer] minimal allowed value
    # @param max [Integer] maximum allowed value
    def parameter_allocated_storage(instance_name, default: 5, min: 5, max: 1024)
      parameter "#{instance_name}AllocatedStorage",
        :Default => default.to_s,
        :Description => "The size of the #{instance_name} (Gb)",
        :Type => 'Number',
        :MinValue => min.to_s,
        :MaxValue => max.to_s,
        :ConstraintDescription => "must be between #{min} and #{max}Gb."
    end

    # IAM profile for s3
    def iam_s3_instance_profile
      resource 'S3AccessRole', :Type => 'AWS::IAM::Role', :Properties => {
        :AssumeRolePolicyDocument => {
          :Statement => [
            {
              :Effect => 'Allow',
              :Principal => { :Service => [ 'ec2.amazonaws.com' ] },
              :Action => [ 'sts:AssumeRole' ],
            },
          ],
        },
        :Path => '/',
      }

      resource 'S3RolePolicies', :Type => 'AWS::IAM::Policy', :Properties => {
        :PolicyName => 's3access',
        :PolicyDocument => {
          :Statement => [
            { :Effect => 'Allow', :Action => 's3:*', :Resource => '*' },
          ],
        },
        :Roles => [ ref('S3AccessRole') ],
      }

      resource 'S3InstanceProfile', :Type => 'AWS::IAM::InstanceProfile', :Properties => {
        :Path => '/',
        :Roles => [ ref('S3AccessRole') ],
      }

      ref('S3InstanceProfile')
    end

    # Instance class (type) parameter
    #
    # @param instance_name [String] instance name
    # @param default [String] default instance type
    # @param allowed_values [Array] list of allowed values
    def parameter_instance_class(instance_name, default: 't2.micro', allowed_values:[])
      allowed = allowed_values.any? ? allowed_values :
        %w(t1.micro t2.micro t2.small t2.medium m1.small m1.medium
                   m1.large m1.xlarge m2.xlarge m2.2xlarge m2.4xlarge m3.medium
                   m3.large m3.xlarge m3.2xlarge c1.medium c1.xlarge c3.large
                   c3.xlarge c3.2xlarge c3.4xlarge c3.8xlarge c4.large c4.xlarge
                   c4.2xlarge c4.4xlarge c4.8xlarge g2.2xlarge r3.large r3.xlarge
                   r3.2xlarge r3.4xlarge r3.8xlarge i2.xlarge i2.2xlarge i2.4xlarge
                   i2.8xlarge hi1.4xlarge hs1.8xlarge cr1.8xlarge cc2.8xlarge cg1.4xlarge)

      parameter "#{instance_name}InstanceClass",
        :Default => default,
        :Description => "The #{instance_name} instance type",
        :Type => 'String',
        :AllowedValues => allowed,
        :ConstraintDescription => "must select a valid #{instance_name} instance type."
    end

    # @deprecated calling instance method directly is deprecated, use instance_vpc or instance_with_network instead
    # Create ec2 instance
    #
    # @param name [String] instance name
    # @param image_id [String] instance ami_id
    # @param subnet [String] instance subnet id
    # @param security_groups [String] instance security_groups (string of Security Groups IDs)
    # @param dependsOn [Array] resources necessary to be create prior to this instance
    # @param properties [Hash] other properties
    def instance(name, image_id, subnet, security_groups, dependsOn:[], properties:{})
      warn '[Deprecated] Use instance_vpc or instance_with_network instead'
      raise "Non VPC instance #{name} can not contain NetworkInterfaces" if properties.include?(:NetworkInterfaces)
      raise "Non VPC instance #{name} can not contain VPC SecurityGroups" if properties.include?(:SecurityGroupIds)
    end

    # Create ec2 instance in given vpc
    #
    # @param name [String] instance name
    # @param image_id [String] instance ami_id
    # @param subnet [String] instance subnet id
    # @param security_groups [String] instance security_groups (string of Security Groups IDs)
    # @param dependsOn [Array] resources necessary to be create prior to this instance
    # @param properties [Hash] other properties
    def instance_vpc(name, image_id, subnet, security_groups, dependsOn:[], properties:{})
      raise "VPC instance #{name} can not contain NetworkInterfaces and subnet or security_groups" if properties.include?(:NetworkInterfaces)
      raise "VPC instance #{name} can not contain non VPC SecurityGroups" if properties.include?(:SecurityGroups)
      properties[:ImageId] = image_id
      properties[:SubnetId] = subnet
      properties[:SecurityGroupIds] = security_groups
      if properties[:Tags] && !properties[:Tags].any?{|x| x[:Key] == 'Name'}
        properties[:Tags] += {:Key => 'Name', :Value => join('-', aws_stack_name, name)}
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
    # @param name [String] instance name
    # @param image_id [String] instance ami_id
    # @param network_interfaces [String] network interfaces
    # @param properties [Hash] other properties
    def instance_with_network(name, image_id, network_interfaces, properties:{})
      raise "Instance with NetworkInterfaces #{name} can not contain instance subnet or security_groups" if ([:SubnetId, :SecurityGroups, :SecurityGroupIds] & properties).any?
      properties[:ImageId] = image_id
      properties[:NetworkInterfaces] = network_interfaces
      if properties[:Tags] &&  !properties[:Tags].any?{|x| x[:Key] == 'Name'}
        properties[:Tags] += {:Key => 'Name', :Value => join('-', aws_stack_name, name)}
      end
      options = {
        :Type => 'AWS::EC2::Instance',
        :Properties => properties
      }
      resource name, options
    end

    def parameter(name, options)
      default(:Parameters, {})[name] = options
      @parameters[name] ||= options[:Default]
      self.class.send(:define_method, :"ref_#{name.underscore}") do
        ref(name)
      end
    end

    # Adds block to the run queue
    #
    # @param items [Array] list of blocks
    def enqueue(items)
      (@run_queue ||= []).concat( items || [] )
    end

    # Determine content of run queue and execute each block in queue in sequence
    def exec!
      enqueue(@pre_run_blocks) if @options[:pre_run]

      enqueue([ @options[:expand] ? Proc.new { puts JSON.pretty_generate(self) } : Proc.new { cfn_cmd(self) } ])

      enqueue(@post_run_blocks) if @options[:post_run]

      @run_queue.each(&:call) if @run_queue
    end

    # Run aws sdk cloud-formation command with stack configuration and parameters
    #
    # @param template [RichTemplateDSL] cloudformation template
    def cfn_cmd(template)

      command = %q{aws cloudformation}

      command += @options[:create_stack] ? ' create-stack' : ' update-stack'

      if @options[:stack_name]
        stack_name = @options[:stack_name]
        command += " --stack-name #{stack_name}"
      end

      if @options[:region]
        region = @options[:region]
        command += " --region #{region}"
      end

      if @options[:capabilities]
        capabilities = @options[:capabilities]
        command += " --capabilities #{capabilities}"
      end

      if @options[:parameters]
        params = @options[:parameters].split(';').map do |x|
          key, val = x.split('=')
          {:ParameterKey => key, :ParameterValue => val}
        end

        command += " --parameters '#{params.to_json}'"
      end

      command += " --template-body '#{template.to_json}'"

      # TODO: separate command setup and actual system call to its own methods
      system(command)
    end

  end
end
