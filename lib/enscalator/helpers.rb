# -*- encoding : utf-8 -*-

require 'open3'
require 'ruby-progressbar'
require 'aws-sdk'

module Enscalator

  # Collection of helper classes and static methods
  module Helpers

    # Executed command as sub-processes with stdout and stderr streams
    #  taken from: https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
    class Subprocess

      # Create new subprocess and execute command there
      #
      # @param cmd [String] command to be executed
      def initialize(cmd)
        # standard input is not used
        Open3.popen3(cmd) do |_stdin, stdout, stderr, thread|
          {:out => stdout, :err => stderr}.each do |key, stream|
            Thread.new do
              until (line = stream.gets).nil? do
                # yield the block depending on the stream
                if key == :out
                  yield line, nil, thread if block_given?
                else
                  yield nil, line, thread if block_given?
                end
              end
            end
          end

          thread.join # wait for external process to finish
        end
      end
    end

    # Run command and print captured output to corresponding standard streams
    #
    # @param cmd [Array] command array to be executed
    # @return [String] produced output from executed command
    def run_cmd(cmd)
      # use contracts to get rid of exceptions: https://github.com/egonSchiele/contracts.ruby
      raise ArgumentError, "Expected Array, but actually was given #{cmd.class}" unless cmd.is_a?(Array)
      raise ArgumentError, 'Argument cannot be empty' if cmd.empty?
      command = cmd.join(' ')
      Subprocess.new command do |stdout, stderr, _thread|
        STDOUT.puts stdout if stdout
        STDERR.puts stderr if stderr
      end
    end

    # Cloudformation client
    #
    # @param region [String] Region in Amazon AWS
    # @raise [ArgumentError] when region is not given
    # @return [Aws::CloudFormation::Client]
    def cfn_client(region)
      raise ArgumentError,
            'Unable to proceed without region' if region.blank?
      Aws::CloudFormation::Client.new(region: region)
    end

    # Cloudformation resource
    #
    # @param client [Aws::CloudFormation::Client] instance of AWS Cloudformation client
    # @raise [ArgumentError] when client is not provided or its not expected class type
    # @return [Aws::CloudFormation::Resource]
    def cfn_resource(client)
      raise ArgumentError,
            'must be instance of Aws::CloudFormation::Client' unless client.instance_of?(Aws::CloudFormation::Client)
      Aws::CloudFormation::Resource.new(client: client)
    end

    # EC2 client
    #
    # @param region [String] Region in Amazon AWS
    # @raise [ArgumentError] when region is not given
    # @return [Aws::EC2::Client]
    def ec2_client(region)
      raise ArgumentError,
            'Unable to proceed without region' if region.blank?
      Aws::EC2::Client.new(region: region)
    end

    # RDS client
    #
    # @param region [String] Region in Amazon AWS
    # @raise [ArgumentError] when region is not given
    # @return [Aws::RDS::Client]
    def rds_client(region)
      raise ArgumentError, 'Unable to proceed without region' if region.blank?
      Aws::RDS::Client.new(region: region)
    end

    # Find ami images registered
    #
    # @param client [Aws::EC2::Client] instance of AWS EC2 client
    # @raise [ArgumentError] when client is not provided or its not expected class type
    # @return [Hash] images satisfying query conditions
    def find_ami(client, owners: ['self'], filters: nil)
      raise ArgumentError,
            'must be instance of Aws::EC2::Client' unless client.instance_of?(Aws::EC2::Client)
      query = {}
      query[:dry_run] = false
      query[:owners] = owners if owners.kind_of?(Array) && owners.any?
      query[:filters] = filters if filters.kind_of?(Array) && filters.any?
      client.describe_images(query)
    end

    # Wait until stack gets created
    #
    # @param cfn [Aws::CloudFormation::Resource] accessor for cloudformation resource
    # @param stack_name [String] name of the stack
    # @return [Aws::CloudFormation::Stack]
    def wait_stack(cfn, stack_name)

      stack = cfn.stack(stack_name)

      title = 'Waiting for stack to be created'
      progress = ProgressBar.create :title => title,
                                    :starting_at => 10,
                                    :total => nil

      loop do
        break unless stack.stack_status =~ /(CREATE|UPDATE)_IN_PROGRESS$/
        progress.title = title + " [#{stack.stack_status}]"
        progress.increment
        sleep 5
        stack = cfn.stack(stack_name)
      end

      stack
    end

    # Get resource for given key from given stack
    #
    # @param stack [Aws::CloudFormation::Stack] cloudformation stack instance
    # @param key [String] resource identifier (key)
    # @return [String] AWS resource identifier
    # @raise [ArgumentError] when stack is nil
    # @raise [ArgumentError] when key is nil or empty
    def get_resource(stack, key)
      raise ArgumentError, 'stack must not be nil' if stack.nil?
      raise ArgumentError, 'key must not be nil nor empty' if key.nil? || key.empty?

      # query with physical_resource_id
      resource = stack.resource(key).physical_resource_id rescue nil
      if resource.nil?
        # fallback to values from stack.outputs
        output = stack.outputs.select { |s| s.output_key == key }
        resource = output.first.output_value rescue nil
      end
      resource
    end

    # Get list of resources for given keys
    #
    # @param stack [Aws::CloudFormation::Stack] cloudformation stack instance
    # @param keys [Array] list of resource identifiers (keys)
    # @return [String] list of AWS resource identifiers
    # @raise [ArgumentError] when stack is nil
    # @raise [ArgumentError] when keys are nil or empty list
    def get_resources(stack, keys)
      raise ArgumentError, 'stack must not be nil' if stack.nil?
      raise ArgumentError, 'key must not be nil nor empty' if keys.nil? || keys.empty?

      keys.map { |k| get_resource(stack, k) }.compact
    end

    # Generate parameters list
    #
    # @param stack [Aws::CloudFormation::Stack] cloudformation stack instance
    # @param keys [Array] list of keys
    def generate_parameters(stack, keys)
      keys.map do |k|
        v = get_resource(stack, k)
        {:parameter_key => k, :parameter_value => v}
      end
    end


    # Call script
    #
    # @param region [String] AWS region identifier
    # @param dependent_stack_name [String] name of the stack current stack depends on
    # @param script_path [String] path to script
    # @param keys [Array] keys
    # @param prepend_args [String] prepend arguments
    # @param append_args [String] append arguments
    # @deprecated this method is no longer used
    def cfn_call_script(region,
                        dependent_stack_name,
                        script_path,
                        keys,
                        prepend_args: '',
                        append_args: '')

      cfn = cfn_resource(cfn_client(region))
      stack = wait_stack(cfn, dependent_stack_name)
      args = get_resources(stack, keys).join(' ')
      cmd = [script_path, prepend_args, args, append_args]

      begin
        run_cmd(cmd)
      rescue Errno::ENOENT
        puts $!.to_s
        STDERR.puts cmd
      end
    end

    # Create stack using cloudformation interface
    #
    # @param region [String] AWS region identifier
    # @param dependent_stack_name [String] name of the stack current stack depends on
    # @param template [String] template name
    # @param stack_name [String] stack name
    # @param keys [Array] keys
    # @param extra_parameters [Array] additional parameters
    # @return [Aws::CloudFormation::Resource]
    # @deprecated this method is no longer used
    def cfn_create_stack(region,
                         dependent_stack_name,
                         template,
                         stack_name,
                         keys: [],
                         extra_parameters: [])

      cfn = cfn_resource(cfn_client(region))
      stack = wait_stack(cfn, dependent_stack_name)

      extra_parameters_cleaned = extra_parameters.map do |x|
        if x.has_key? 'ParameterKey'
          {:parameter_key => x['ParameterKey'], :parameter_value => x['ParameterValue']}
        else
          x
        end
      end

      options = {
        :stack_name => stack_name,
        :template_body => template,
        :parameters => generate_parameters(stack, keys) + extra_parameters_cleaned
      }

      cfn.create_stack(options)
    end

    # Create ssh public/private key pair, save private key for current user
    #
    # @param key_name [String] key name
    # @param region [String] aws region
    # @param force_create [Boolean] force to create a new ssh key
    def create_ssh_key(key_name, region, force_create: false)
      client = ec2_client(region)

      if !client.describe_key_pairs.key_pairs.collect(&:key_name).include?(key_name) || force_create
        # delete existed ssh key
        client.delete_key_pair(key_name: key_name)

        # create a new ssh key
        key_pair = client.create_key_pair(key_name: key_name)
        STDERR.puts "Created new ssh key with fingerprint: #{key_pair.key_fingerprint}"

        # save private key for current user
        private_key = File.join(ENV['HOME'], '.ssh', key_name)
        File.open(private_key, 'w') do |wfile|
          wfile.write(key_pair.key_material)
        end
        File.chmod(0600, private_key)
      else
        key_pair = Aws::EC2::KeyPair.new(key_name, client: client)
        STDERR.puts "Found existing ssh key with fingerprint: #{key_pair.key_fingerprint}"
      end
    end

    # Read user data from file
    #
    # @param app_name [String] application name
    def read_user_data(app_name)
      user_data_path = File.join(File.expand_path('..', __FILE__), 'confs', 'user-data', app_name)
      fail("User data path #{user_data_path} not exists") unless File.exist?(user_data_path)
      File.read(user_data_path)
    end

    # Get current user id for amazon web service
    #
    # @return [String] user id
    def current_aws_user_id
      @current_aws_user_id ||= Aws::IAM::CurrentUser.new(region: 'us-west-1').arn.scan(%r'arn:aws:iam::(\d+):user/.*').flatten.first
    end

    # Get amazon resource name for RDS resource
    #
    # @param region [String] Amazon web service region
    # @param db_instance_identifier [String] RDS db instance identifier
    # @return [String] amazon resource name
    def rds_arn(region, db_instance_identifier)
      "arn:aws:rds:#{region}:#{current_aws_user_id}:db:#{db_instance_identifier}"
    end

    # Get RDS snapshots filtered by tags
    #
    # @param rds_client [Aws::RDS::Client] instance of Aws RDS client
    # @param tags [Array<Hash>] list of tags, tag is Hash with format `{key: 'key', value: 'value'}`
    # @return [Array] list of RDS snapshot instances
    def find_rds_snapshots(rds_client, tags: [])
      db_instances = rds_client.describe_db_instances.db_instances
      target_db_instance = nil
      db_instances.each do |dbi|
        resource_name = rds_arn(rds_client.config.region, dbi.db_instance_identifier)
        tag_list = rds_client.list_tags_for_resource(resource_name: resource_name).tag_list
        # in order to reduce web requests, break immediately once found matched result
        if tags.all? { |tag| !tag_list.select(&->(list) { list.key == tag[:key] && list.value == tag[:value] }).empty? }
          target_db_instance = dbi
          break
        end
      end

      target_db_instance ?
        rds_client.describe_db_snapshots(db_instance_identifier: target_db_instance.db_instance_identifier).db_snapshots :
        []
    end

  end # module Asserts
end # module Enscalator
