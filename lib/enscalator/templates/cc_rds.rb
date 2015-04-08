module Enscalator

  # namespace for template collection
  module Templates

    # Production database for CareerCard
    class CareerCardProductionRDS < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::RDS_Snapshot

      def tpl

        pre_run do
          magic_setup stack_name: 'enjapan-vpc',
                      region: @options[:region]
        end

        description 'Production RDS stack for Career Card'

        rds_snapshot_init('cc-prod-20150331',
                          allocated_storage: 100,
                          multizone: 'true',
                          parameter_group: 'careercard-production-mysql',
                          instance_class: 'db.m3.large')

        post_run do
          region = @options[:region]
          stack_name = @options[:stack_name]
          cfn = cfn_client(@options[:region])

          stack = wait_stack(cfn, stack_name)
          host = get_resource(stack, 'RDSEndpointAddress')

          upsert_dns_record(
              zone_name: 'enjapan.prod.',
              record_name: "rds.#{stack_name}.enjapan.prod.",
              type: 'CNAME', values: [host], ttl: 30)
        end

      end
    end
  end
end


