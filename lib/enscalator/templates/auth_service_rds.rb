module Enscalator

  module Templates

    # Authentication service
    class AuthServiceRDS < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::RDS
      include Enscalator::Plugins::Elb

      def tpl

        pre_run do
          magic_setup stack_name: 'enjapan-vpc',
                      region: @options[:region]
        end

        @db_name = 'Auth'

        description 'Auth service database infrastructure'

        rds_init(@db_name)
        elb_init(@options[:stack_name], @options[:region], ssl: true, internal: true)

        post_run do
          stack_name = @options[:stack_name]
          cfn = cfn_resource(cfn_client(@options[:region]))

          stack = wait_stack(cfn, stack_name)
          host = get_resource(stack, "RDS#{@db_name}EndpointAddress")

          upsert_dns_record(
            zone_name: 'enjapan.local.',
            record_name: "rds.#{stack_name}.enjapan.local.",
            type: 'CNAME', values: [host])
        end

      end
    end
  end
end
