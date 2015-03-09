
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
        description 'JobPosting service network and database infrastructure'

        pre_run do
          magic_setup stack_name: 'enjapan-vpc',
            region: @options[:region],                                                                                                                       
            start_ip_idx: 20
        end

        couchbase_init("Jobposting")

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


      end
    end
  end
end
