# encoding: UTF-8

module Enscalator
  module Templates
    # Production database for Waza backend
    class WazaBackendRDS < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::RDS
      include Enscalator::Plugins::Elb

      def tpl

        pre_run do
          pre_setup stack_name: 'enjapan-vpc',
                    region: @options[:region]
        end

        @db_name = 'WazaBackend'

        description 'RDS stack for Waza backend'

        rds_init(@db_name)
        elb_init(@options[:stack_name], @options[:region], ssl: true, internal: true)

        post_run do
          stack_name = @options[:stack_name]
          cfn = cfn_resource(cfn_client(@options[:region]))

          stack = wait_stack(cfn, stack_name)
          host = get_resource(stack, "RDS#{@db_name}EndpointAddress")

          upsert_dns_record(
              zone_name: 'enjapan.prod.',
              record_name: "rds.#{stack_name}.enjapan.prod.",
              type: 'CNAME', values: [host], ttl: 30)
        end

      end
    end
  end
end


