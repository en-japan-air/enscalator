require 'cloudformation-ruby-dsl/cfntemplate'

module Enscalator
  # DSL specific for enscalator
  class RichTemplateDSL < TemplateDSL
    include Enscalator::Core::CfParameters
    include Enscalator::Core::CfResources
    include Enscalator::Helpers
    include Enscalator::Plugins::Route53

    # Cloudformation limit when sending template body directly
    TEMPLATE_BODY_LIMIT = 51_200

    # Create new RichTemplateDSL instance
    #
    # @param [Hash] options command-line arguments
    def initialize(options = {})
      @options = options
      init_aws_config(@options[:region], profile_name: @options[:profile])
      super(parse_params(@options[:parameters]), @options[:stack_name], @options[:region], false, &proc { tpl })
    end

    # Parse semicolon separated parameter string
    #
    # @param [String] raw_parameters raw parameter string
    # @return [Hash] parameter hash
    def parse_params(raw_parameters)
      Hash[(raw_parameters || '').split(/;/).map { |pair| pair.split(/=/, 2) }]
    end

    # Helper method to check if the current command is to create the stack
    #
    # @return [Truthy] truthful if currently creating a stack
    def creating?
      @options[:create_stack]
    end

    # Helper method to provide accessor for `region`
    #
    # @return [String] region
    def region
      aws_region
    end

    # Helper method to provide value accessor for `vpc_stack_name`
    #
    # @return [String] vpc_stack_name
    # @raise [RuntimeError] if vpc-stack-name was not given
    def vpc_stack_name
      @options[:vpc_stack_name] || fail('Requires vpc-stack-name')
    end

    # Adds trailing dot to make it proper FQDN
    #
    # @param [String] str fqdn string
    # @return [String] fqdn with trailing dot
    def handle_trailing_dot(str)
      str.end_with?('.') ? str : str + '.'
    end

    # @deprecated
    # Hosted zone accessor
    #
    # @return [String] hosted zone, and ensure ending with a '.'
    # @raise [RuntimeError] if hosted zone is accessed but it's not configured
    def hosted_zone
      ActiveSupport::Deprecation.warn('hosted_zone is deprecated (use private_hosted_zone instead)')
      private_hosted_zone
    end

    # Private hosted zone accessor
    #
    # @return [String] private hosted zone
    # @raise [RuntimeError] if private hosted zone was accessed before it was configured
    def private_hosted_zone
      # TODO: adjust other templates/plugins to use private_hosted_zone
      @options[:private_hosted_zone] || fail('Private hosted zone has to be configured')
      handle_trailing_dot(@options[:private_hosted_zone])
    end

    # Public hosted zone accessor
    #
    # @return [String] public hosted zone
    # @raise [RuntimeError] if hosted zone was accessed before it was configured
    def public_hosted_zone
      @options[:public_hosted_zone] || fail('Public hosted zone has to be configured')
      handle_trailing_dot(@options[:public_hosted_zone])
    end

    # Get a list of availability zones for the given region
    def read_availability_zones
      az = @options[:availability_zone]
      supported_az = ec2_client(region).describe_availability_zones.availability_zones
      alive_az = supported_az.select { |zone| zone.state == 'available' }
      az_list = alive_az.collect(&:zone_name).map { |n| [n.last.to_sym, n] }.to_h

      # use all zones, specific one, or fail if zone is not supported in given region
      if az == 'all'
        az_list
      elsif az.split(',').map(&:to_sym).all?{|x| az_list.include?(x)}
        az_list.select { |k, _| az.split(',').map(&:to_sym).include?(k) }
      else
        fail("Requested zone #{az} is not supported in #{region}, supported ones are #{az_list.keys.join(',')}")
      end
    end

    # Availability zones accessor
    def availability_zones
      @availability_zones ||= read_availability_zones
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
      tags.map { |k, v| { Key: k, Value: v } }
    end

    # Template description
    #
    # @param [String] desc template description
    def description(desc)
      value(Description: desc)
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
      return nil unless options[:Type] && %w(AWS::EC2::Instance).include?(options[:Type])
      output "#{name}PrivateIpAddress",
             Description: "#{name} Private IP Address",
             Value: get_att(name, 'PrivateIp')
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
      init_assets_dir
      enqueue(@pre_run_blocks) if @options[:pre_run]
      enqueue([@options[:expand] ? proc { STDOUT.puts(JSON.pretty_generate(self)) } : proc { STDOUT.puts(deploy(self)) }])
      enqueue(@post_run_blocks) if @options[:post_run]
      @run_queue.each(&:call) if @run_queue
    end

    # Pass generated template to underlying cloudformation client to actually create/update stack
    # @param [TemplateDSL] template instance of template
    # @raise [RuntimeError] when generated template exceeds 51200 size limit
    def deploy(template)
      template_body = template.to_json
      if template_body.bytesize > TEMPLATE_BODY_LIMIT
        fail("Unable to deploy template exceeding #{TEMPLATE_BODY_LIMIT} limit: #{template_body.bytesize}")
      end
      options = {
        stack_name: stack_name,
        capabilities: [@options[:capabilities]],
        template_body: template_body
      }
      options[:parameters] = parameters.map { |k, v| { parameter_key: k, parameter_value: v } } unless parameters.empty?
      action = @options[:update_stack] ? :update_stack : :create_stack
      resp = cfn_client(region).send(action, options)
      resp.stack_id
    end
  end # class RichTemplateDSL
end # module Enscalator
