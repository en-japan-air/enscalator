
module Enscalator
  module Templates
    class JobPosting < Enscalator::EnAppTemplateDSL
      include Couchbase

      def initialize(options={})
        @options = options
        block = Proc.new { tpl }
        super(&block)
      end

      def tpl
        pre_run do
          region = @options[:region]
          client = Aws::CloudFormation::Client.new(region: region)
          cfn = Aws::CloudFormation::Resource.new(client: client)
          stack = cfn.stack('enjapan-vpc')
          vpc_id = select_output(stack.outputs, 'VpcId')
          private_security_group = select_output(stack.outputs, 'PrivateSecurityGroup')
          private_route_tables = { 'a' => get_resource(stack, 'PrivateRouteTable1'),
                                   'c' => get_resource(stack, 'PrivateRouteTable2') }

          basic_setup vpc: vpc_id,
            start_ip_idx: 20,
            private_security_group: private_security_group,
            private_route_tables: private_route_tables
        end

        post_run do
          region = @options[:region]
          stack_name = @options[:stack_name]
          client = Aws::CloudFormation::Client.new(region: region)
          cfn = Aws::CloudFormation::Resource.new(client: client)

          stack = wait_stack(cfn, stack_name)
          ipaddr = get_resource(stack, 'CouchbaseJobpostingPrivateIpAddress')

          upsert_dns_record(zone_name: 'enjapan.local.',
                            record_name: "couchbase.#{stack_name}.enjapan.local.",
          type: 'A', region: region, values: [ipaddr])
        end

        couchbase_init("Jobposting")

        description 'JobPosting service network and database infrastructure'

      end
    end
  end
end
