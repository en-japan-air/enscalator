module Helpers
  module Mocks
    # RichTemplateDSL class generator
    def gen_richtemplate(name,
                         superclass = Enscalator::RichTemplateDSL,
                         includes = [],
                         &block)
      Class.new(superclass) do
        Object.send(:remove_const, name.to_sym) if Object.const_defined?(name.to_sym)
        Object.const_set(name.to_sym, self)
        includes.each { |mod| include mod } unless includes.empty?
        define_method(:tpl, &block)
      end
    end

    # default testing command-line options
    def default_cmd_opts(template, stack_name)
      {
        template: template,
        stack_name: stack_name,
        vpc_stack_name: 'enjapan-vpc',
        region: 'us-east-1',
        hosted_zone: 'test',
        parameters: nil,
        list_templates: false,
        expand: true,
        create_stack: false,
        update_stack: false,
        pre_run: true,
        post_run: false,
        capabilities: 'CAPABILITY_IAM',
        availability_zone: 'all'
      }
    end

    # should be called from within template mock
    def mock_availability_zones
      self.class_eval do
        define_method('availability_zones') do
          {
            a: 'us-east-1a',
            b: 'us-east-1b',
            c: 'us-east-1c',
            e: 'us-east-1e'
          }
        end
      end
    end # def mock_availability_zones
  end # module Mocks
end # module Helpers