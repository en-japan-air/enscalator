module Helpers

  module CommandLine

    # default testing command-line options
    def default_cmd_opts
      {
        template: RichTemplateFixture.name.demodulize,
        stack_name: RichTemplateFixture.name.downcase,
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

    # mock `availability_zones`
    def mock_availability_zones
      Enscalator::RichTemplateDSL.class_eval do
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