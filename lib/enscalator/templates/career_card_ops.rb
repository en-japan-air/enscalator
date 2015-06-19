# encoding: UTF-8

module Enscalator
  module Templates
    # Production database for Waza backend
    class CareerCardOps < Enscalator::EnAppTemplateDSL
      include Enscalator::Helpers
      include Enscalator::Plugins::RDS
      include Enscalator::Plugins::Elb
      include Enscalator::Plugins::AutoScale

      def tpl
        # get the latest uploaded image's id
        image = find_ami(ec2_client(region), filters: [{name: 'tag:Name', values: [app_name]}])
                  .images
                  .sort { |a, b| a.creation_date <=> b.creation_date }
                  .last || fail("Cannot find valid image in region: '#{region}'")

        pre_run { load_vpc_params }

        @db_name = 'CareerCardOps'

        description 'Stack for CareerCardOps backend'

        parameter_instance_class app_name,
                                 default: 'm3.medium'

        rds_init(@db_name)
        elb_resource_name = elb_init(stack_name,
                                     region,
                                     zone_name: hosted_zone,
                                     ssl: false,
                                     internal: false)

        auto_scale_init image.image_id,
                        auto_scale_name: app_name,
                        launch_config_props: {
                          InstanceType: ref("#{app_name}InstanceClass"),
                          # add user data here if necessary
                          UserData: Base64.encode64('')
                        },
                        auto_scale_props: {
                          MinSize: 0,
                          MaxSize: 3,
                          DesiredCapacity: 1,
                          LoadBalancerNames: [
                            ref(elb_resource_name)
                          ]
                        }

        post_run do

          stack_name = @options[:stack_name]
          cfn = cfn_resource(cfn_client(region))

          stack = wait_stack(cfn, stack_name)
          host = get_resource(stack, "RDS#{@db_name}EndpointAddress")

          upsert_dns_record(zone_name: hosted_zone,
                            record_name: "rds.#{stack_name}.#{hosted_zone}",
                            type: 'CNAME',
                            values: [host],
                            ttl: 30,
                            region: region)


        end

      end
    end
  end
end


