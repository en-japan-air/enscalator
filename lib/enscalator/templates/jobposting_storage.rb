
module Enscalator
  module Templates
    class JobpostingStorage < Enscalator::EnAppTemplateDSL
      include Elasticsearch # Include the Elasticsearch plugin for couchbase_init()

      def initialize(options={})
        @options = options # Options contains the cli args
        block = Proc.new { tpl }
        super(&block)
      end

      def tpl
        description 'JobpostingStorage service network and database infrastructure'

        # pre_run takes a block and will be the first method called
        pre_run do
          magic_setup stack_name: 'enjapan-vpc',
            region: @options[:region],
            start_ip_idx: 20 # The start ip address inside the subnet for this template
        end

        elasticsearch_init("JobpostingStorage") # Create a couchbase instance with name "JobpostingStorage"

        # post_run will be run after the create-stack call is started
        post_run do
          region = @options[:region]
          stack_name = @options[:stack_name]
          client = Aws::CloudFormation::Client.new(region: region)
          cfn = Aws::CloudFormation::Resource.new(client: client)

          stack = wait_stack(cfn, stack_name) # Wait for the stack to be created
          ipaddr = get_resource(stack, 'ElasticsearchJobpostingStoragePrivateIpAddress') # Get couchbase instance IP address

          # Create a DNS record in route53 for the couchbase instance
          upsert_dns_record(
            zone_name: 'enjapan.local.',
            record_name: "elasticsearch.#{stack_name}.enjapan.local.",
            type: 'A', region: region, values: [ipaddr]
          )
        end


      end
    end
  end
end
