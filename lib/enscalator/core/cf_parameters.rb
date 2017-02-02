module Enscalator
  module Core
    # Parameters for cloudformation template dsl
    module CfParameters
      # Key name parameter
      #
      # @param [String] instance_name for which ssh key was created
      def parameter_key_name(instance_name)
        parameter "#{instance_name}KeyName",
                  Description: "Name of the #{instance_name} ssh key pair",
                  Type: 'String',
                  MinLength: '1',
                  MaxLength: '64',
                  AllowedPattern: '[a-zA-Z][-_a-zA-Z0-9]*',
                  ConstraintDescription: 'can contain only alphanumeric characters, dashes and underscores.'
      end

      # Name parameter
      #
      # @param [String] instance_name instance name
      # @param [String] default default name
      # @param [Integer] min_length minimum length
      # @param [Integer] max_length maximum length
      def parameter_name(instance_name, default: nil, min_length: 1, max_length: 64)
        parameter "#{instance_name}Name",
                  Default: default ? default.to_s : "#{instance_name}",
                  Description: "#{instance_name} name",
                  Type: 'String',
                  MinLength: min_length,
                  MaxLength: max_length,
                  AllowedPattern: '[a-zA-Z][a-zA-Z0-9]*',
                  ConstraintDescription: 'must begin with a letter and contain only alphanumeric characters.'
      end

      # Username parameter
      #
      # @param [String] instance_name instance name
      # @param [String] default default username
      # @param [Integer] min_length minimum length
      # @param [Integer] max_length maximum length
      def parameter_username(instance_name, default: 'root', min_length: 1, max_length: 16)
        parameter "#{instance_name}Username",
                  Default: default,
                  NoEcho: 'true',
                  Description: "Username for #{instance_name} access",
                  Type: 'String',
                  MinLength: min_length,
                  MaxLength: max_length,
                  AllowedPattern: '[a-zA-Z][a-zA-Z0-9]*',
                  ConstraintDescription: 'must begin with a letter and contain only alphanumeric characters.'
      end

      # Password parameter
      #
      # @param [String] instance_name instance name
      # @param [String] default default value
      # @param [Integer] min_length minimum length
      # @param [Integer] max_length maximum length
      def parameter_password(instance_name, default: 'password', min_length: 8, max_length: 41)
        parameter "#{instance_name}Password",
                  Default: default,
                  NoEcho: 'true',
                  Description: "Password for #{instance_name} access",
                  Type: 'String',
                  MinLength: min_length,
                  MaxLength: max_length,
                  AllowedPattern: '[a-zA-Z0-9]*',
                  ConstraintDescription: 'must contain only alphanumeric characters.'
      end

      # Allocated storage parameter
      #
      # @param [String] instance_name instance name
      # @param [String] default size of instance primary storage
      # @param [Integer] min minimal allowed value
      # @param [Integer] max maximum allowed value
      def parameter_allocated_storage(instance_name, default: 5, min: 5, max: 1024)
        parameter "#{instance_name}AllocatedStorage",
                  Default: default.to_s,
                  Description: "The size of the #{instance_name} (Gb)",
                  Type: 'Number',
                  MinValue: min.to_s,
                  MaxValue: max.to_s,
                  ConstraintDescription: "must be between #{min} and #{max}Gb."
      end

      # Ami image parameter
      #
      # @param [String] name ami of the ami
      # @param [String] ami_id id of the ami
      # @return [String] parameter name
      def parameter_ami(name, ami_id)
        parameter_name = "#{name}AMIId"
        parameter parameter_name,
                  Default: ami_id,
                  Description: "The #{name} AMI id",
                  Type: 'String',
                  AllowedPattern: 'ami-[a-zA-Z0-9]*',
                  ConstraintDescription: 'must be valid AMI id (ami-*).'
        parameter_name
      end

      # Instance type parameter
      #
      # @param [String] instance_name instance name
      # @param [String] type instance type (default: t2.micro)
      # @param [Array] allowed_values list used to override built-in instance types
      def parameter_instance_type(instance_name, type, allowed_values: [])
        # check if given type is included in allowed_values and fails if none matched
        unless allowed_values.any? { |v| v == type }
          fail("Instance type \"#{type}\" is not in allowed values: #{allowed_values.join(' ')}")
        end
        name = "#{instance_name}InstanceType"
        parameter name,
                  Default: type,
                  Description: "The #{instance_name} instance type",
                  Type: 'String',
                  AllowedValues: allowed_values,
                  ConstraintDescription: 'must be valid EC2 instance type.'
        name
      end

      # EC2 Instance type parameter
      #
      # @param [String] instance_name name of the instance
      # @param [String] type instance type
      def parameter_ec2_instance_type(instance_name,
                                      type: InstanceType.ec2_instance_type.current_generation[:general_purpose].first)
        fail("Not supported instance type: #{type}") unless InstanceType.ec2_instance_type.supported?(type)
        warn("Using obsolete instance type: #{type}") if InstanceType.ec2_instance_type.obsolete?(type)
        parameter_instance_type(instance_name, type, allowed_values: InstanceType.ec2_instance_type.allowed_values(type))
      end

      # RDS Instance type parameter
      #
      # @param [String] instance_name name of the instance
      # @param [String] type instance type
      def parameter_rds_instance_type(instance_name,
                                      type: InstanceType.rds_instance_type.current_generation[:general_purpose].first)
        fail("Not supported instance type: #{type}") unless InstanceType.rds_instance_type.supported?(type)
        warn("Using obsolete instance type: #{type}") if InstanceType.rds_instance_type.obsolete?(type)
        parameter_instance_type(instance_name, type, allowed_values: InstanceType.rds_instance_type.allowed_values(type))
      end
    end
  end
end
