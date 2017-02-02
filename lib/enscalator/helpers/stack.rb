require 'ruby-progressbar'

module Enscalator
  module Helpers
    # Helpers for operations requiring stack instance or stack_name
    module Stack
      # Wait until stack gets created
      #
      # @param [Aws::CloudFormation::Resource] cfn accessor for cloudformation resource
      # @param [String] stack_name name of the stack
      # @return [Aws::CloudFormation::Stack]
      def wait_stack(cfn, stack_name)
        stack = cfn.stack(stack_name)
        title = 'Waiting for stack to be created'
        progress = ProgressBar.create(title: title, starting_at: 10, total: nil)
        loop do
          break unless stack.stack_status =~ /(CREATE|UPDATE)_IN_PROGRESS$/
          progress.title = title + " [#{stack.stack_status}]"
          progress.increment
          sleep 5
          stack = cfn.stack(stack_name)
        end
        stack
      end

      # Create stack using cloudformation interface
      #
      # @param [String] region AWS region identifier
      # @param [String] dependent_stack_name name of the stack current stack depends on
      # @param [String] template name
      # @param [String] stack_name stack name
      # @param [Array] keys keys
      # @param [Array] extra_parameters additional parameters
      # @return [Aws::CloudFormation::Resource]
      # @deprecated this method is no longer used
      def cfn_create_stack(region, dependent_stack_name, template, stack_name, keys: [], extra_parameters: [])
        cfn = cfn_resource(cfn_client(region))
        stack = wait_stack(cfn, dependent_stack_name)
        extra_parameters_cleaned = extra_parameters.map do |x|
          if x.key? 'ParameterKey'
            {
              parameter_key: x['ParameterKey'],
              parameter_value: x['ParameterValue']
            }
          else
            x
          end
        end
        options = {
          stack_name: stack_name,
          template_body: template,
          parameters: generate_parameters(stack, keys) + extra_parameters_cleaned
        }
        cfn.create_stack(options)
      end

      # Get resource for given key from given stack
      #
      # @param [Aws::CloudFormation::Stack] stack cloudformation stack instance
      # @param [String] key resource identifier (key)
      # @return [String] AWS resource identifier
      # @raise [ArgumentError] when stack is nil
      # @raise [ArgumentError] when key is nil or empty
      def get_resource(stack, key)
        fail ArgumentError, 'stack must not be nil' if stack.nil?
        fail ArgumentError, 'key must not be nil nor empty' if key.nil? || key.empty?
        # query with physical_resource_id
        resource = begin
          stack.resource(key).physical_resource_id
        rescue RuntimeError
          nil
        end
        if resource.nil?
          # fallback to values from stack.outputs
          output = stack.outputs.select { |s| s.output_key == key }
          resource = begin
            output.first.output_value
          rescue RuntimeError
            nil
          end
        end
        resource
      end

      # Get list of resources for given keys
      #
      # @param [Aws::CloudFormation::Stack] stack cloudformation stack instance
      # @param [Array] keys list of resource identifiers (keys)
      # @return [String] list of AWS resource identifiers
      # @raise [ArgumentError] when stack is nil
      # @raise [ArgumentError] when keys are nil or empty list
      def get_resources(stack, keys)
        fail ArgumentError, 'stack must not be nil' if stack.nil?
        fail ArgumentError, 'key must not be nil nor empty' if keys.nil? || keys.empty?
        keys.map { |k| get_resource(stack, k) }.compact
      end

      # Generate parameters list
      #
      # @param [Aws::CloudFormation::Stack] stack cloudformation stack instance
      # @param [Array] keys list of keys
      def generate_parameters(stack, keys)
        keys.map { |k| { parameter_key: k, parameter_value: get_resource(stack, k) } }
      end
    end
  end
end
