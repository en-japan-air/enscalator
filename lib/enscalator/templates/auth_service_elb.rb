# encoding: UTF-8

module Enscalator

  module Templates

    # CareerCard Landing Page generator
    class AuthServiceELB < Enscalator::EnAppTemplateDSL
      include Enscalator::Helpers
      include Enscalator::Plugins::Elb

      def tpl
        @app_name = self.class.name.split('::').last

        pre_run do
          pre_setup stack_name: 'enjapan-vpc',
            region: @options[:region]
        end

        description 'AuthService ELB'

        elb_init(@options[:stack_name], @options[:region], ssl: true, internal: false)
      end # def tpl

    end # class AuthServiceELB
  end # module Templates
end # module Enscalator
