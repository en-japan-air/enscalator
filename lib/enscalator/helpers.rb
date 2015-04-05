require 'open3'
require 'ruby-progressbar'

module Enscalator
  module Helpers

    # Executed command as sub-processes with stdout and stderr streams
    #  taken from: https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
    class Subprocess

      # Create new subprocess and executed cmd
      #
      # @param cmd [String] command to be executed
      # @param block [Proc] block handling stdout, stderr and thread
      def initialize(cmd, &block)
        # standard input is not used
        Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
          { :out => stdout, :err => stderr }.each do |key, stream|
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
      raise ArgumentError, "Expected Array, but actually was given #{cmd.class}" unless cmd.is_a?(Array)
      raise ArgumentError, 'Argument cannot be empty' if cmd.empty?
      command = cmd.join(' ')
      Subprocess.new command do |stdout, stderr, thread|
        STDOUT.puts stdout if stdout
        STDERR.puts stderr if stderr
      end
    end

    # Cloudformation client
    #
    # @param region [String] Region in Amazon AWS
    # @return [Aws::CloudFormation::Resource]
    def cfn_client(region)
      raise RuntimeError, 'Unable to proceed without region' if region && region.empty?
      client = Aws::CloudFormation::Client.new(region: region)
      Aws::CloudFormation::Resource.new(client: client)
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

    # TODO: refactor -> move logic to get_resource
    def select_output(outputs, key)
      outputs.select { |a| a.output_key == key }.first.output_value
    end

    # TODO: refactor -> move logic to get_resource
    def select_outputs(outputs, keys)
      keys.map { |k| select_output(outputs, k) }
    end

    # Get resource for given key from given stack
    #
    # @param stack [Aws::CloudFormation::Stack] cloudformation stack instance
    # @param key [String] resource identifier (key)
    # @return [String] AWS resource identifier
    def get_resource(stack, key)
      resource = stack.resource(key).physical_resource_id rescue nil
      resource.nil? ? select_output(stack.outputs, key) : resource
    end

    # Generate parameters list
    #
    # @param stack [Aws::CloudFormation::Stack] cloudformation stack instance
    # @param keys [Array] list of keys
    def generate_parameters(stack, keys)
      keys.map do |k|
        v = get_resource(stack,k)
        { :parameter_key => k, :parameter_value => v }
      end
    end

    # @deprecated this method is not used anymore
    def cfn_call_script(region,
                    dependent_stack_name,
                    script_path,
                    keys,
                    prepend_args: '',
                    append_args: '')

      cfn = cfn_client(region)
      stack = wait_stack(cfn, dependent_stack_name)
      args = select_outputs(stack.outputs,keys).join(' ')

      cmd = [script_path, prepend_args, args, append_args]

      run_cmd

      begin
        res = run_cmd(cmd)
        puts res
      rescue RuntimeError
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
    # @deprecated this method is not used anymore
    #  Cloudformation already have create_stack method, thus including this module would throw this exception:
    #  Aws::Resources::Errors::DefinitionError: unable to define method #create_stack, method already exists
    def cfn_create_stack(region,
                     dependent_stack_name,
                     template,
                     stack_name,
                     keys: [],
                     extra_parameters:[])

      cfn = cfn_client(region)
      stack = wait_stack(cfn, dependent_stack_name)

      extra_parameters_cleaned = extra_parameters.map do |x|
        if x.has_key? 'ParameterKey'
          { :parameter_key => x['ParameterKey'], :parameter_value => x['ParameterValue']}
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

  end # module Helpers
end # module Enscalator
