# encoding: UTF-8

module Enscalator

  module Templates

    # Production database for CareerCard
    class CareerCardProductionRDS < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::RDS

      def tpl

        pre_run do
          pre_setup stack_name: 'enjapan-vpc',
                    region: @options[:region]
        end

        @db_name = 'ccprod'

        description 'Production RDS stack for Career Card'

        rds_init(@db_name,
                 snapshot_id: 'cc-prod-20150331',
                 allocated_storage: 100,
                 multizone: 'true',
                 parameter_group: 'careercard-production-mysql',
                 instance_class: 'db.m3.large',
                 properties: {
                     Tags: [
                         {
                             Key: 'Billing',
                             Value: 'CareerCard'
                         }
                     ]
                 }
        )

        post_run do
          stack_name = @options[:stack_name]
          cfn = cfn_resource(cfn_client(@options[:region]))

          stack = wait_stack(cfn, stack_name)
          host = get_resource(stack, "RDS#{@db_name}EndpointAddress")

          upsert_dns_record(
              zone_name: 'enjapan.prod.',
              record_name: "rds.#{stack_name}.enjapan.prod.",
              type: 'CNAME', values: [host], ttl: 30, region: @options[:region])
        end

      end
    end
  end
end


