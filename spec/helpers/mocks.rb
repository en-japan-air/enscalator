module Helpers

  module Mocks

    class RichTemplateFixture < Enscalator::RichTemplateDSL
      define_method :tpl do
        @app_name = self.class.name.demodulize
        value Description: 'test template'
      end
    end

    # richtemplate class generator
    def gen_richtemplate(superclass = Enscalator::RichTemplateDSL,
                         includes = [],
                         &block)
      Class.new(superclass) do
        includes.each { |mod| include mod } unless includes.empty?
        define_method(:tpl, &block)
      end
    end

    # TODO: remove dependency on RichTemplateFixture
    # default testing command-line options
    def default_cmd_opts(template = RichTemplateFixture.name.demodulize,
                         stack_name = RichTemplateFixture.name.downcase.demodulize)
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
    end

  end # module CommandLine
end # module Helpers