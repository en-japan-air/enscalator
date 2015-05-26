# encoding: UTF-8

module Enscalator
  module Templates 
    class WazaBackendELB < Enscalator::EnAppTemplateDSL
      include Enscalator::Helpers
      include Enscalator::Plugins::Elb

      def tpl
        @app_name = self.class.name.split('::').last

        pre_run do
          pre_setup stack_name: 'enjapan-vpc',
            region: @options[:region]
        end

        description 'Waza backend ELB'

        elb_init(@options[:stack_name], @options[:region], ssl: true, internal: false)
      end # def tpl

    end # class WazaBackendELB
  end # module Templates
end # module Enscalator
