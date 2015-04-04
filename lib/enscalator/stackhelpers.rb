# require 'aws-sdk'

module Enscalator
  module StackHelpers

    def cfn_client(region)
      raise RuntimeError, 'Unable to proceed without region' if region && region.empty?
      client = Aws::CloudFormation::Client.new(region: region)
      Aws::CloudFormation::Resource.new(client: client)
    end

    def run_cmd(cmd)
      run = `#{cmd}`
      raise RuntimeError, $? if $?.to_i != 0
      run
    end

    def wait_stack(cfn, stack_name)

      stack = cfn.stack(stack_name)

      # TODO: use gem curses to provide more friendly output
      loop do
        break unless stack.stack_status =~ /(CREATE|UPDATE)_IN_PROGRESS$/
          STDERR.puts "Waiting for stack to be created, currently #{stack.stack_status}"
        sleep 5
        stack = cfn.stack(stack_name)
      end

      stack
    end

    def select_output(outputs, key)
      outputs.select { |a| a.output_key == key }.first.output_value
    end

    def select_outputs(outputs, keys)
      keys.map { |k| select_output(outputs, k) }
    end

    def get_resource(stack, key)
      resource = stack.resource(key).physical_resource_id rescue nil
      resource.nil? ? select_output(stack.outputs,key) : resource
    end

    def generate_parameters(stack, keys)
      keys.map do |k|
        v = get_resource(stack,k)
        { :parameter_key => k, :parameter_value => v }
      end
    end

    # @deprecated cloudformation command is not used anymore
    def call_script(region,
                    dependent_stack_name,
                    script_path,
                    keys,
                    prepend_args: '',
                    append_args: '')

      cfn = cfn_client(region)
      stack = wait_stack(cfn, dependent_stack_name)
      args = select_outputs(stack.outputs,keys).join(' ')

      cmd = "#{script_path} #{prepend_args} #{args} #{append_args}"
      begin
        res = run_cmd(cmd)
        puts res
      rescue RuntimeError
         puts $!.to_s
         STDERR.puts cmd
      end
    end

    # @deprecated cloudformation command is not used anymore
    def create_stack(region,
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

  end # module StackHelpers
end # module Enscalator
