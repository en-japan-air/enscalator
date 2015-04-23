# encoding: UTF-8

module Enscalator

  module Templates

    # Template for JobPosting storage
    class JobPostingStorage < Enscalator::EnAppTemplateDSL

      # include the Elasticsearch plugin for couchbase_init()
      include Enscalator::Plugins::Elasticsearch

      def tpl

        # pre_run takes a block and will be the first method called
        pre_run do
          magic_setup stack_name: 'enjapan-vpc',
                      region: @options[:region]
        end

        description 'JobPostingStorage service network and database infrastructure'

        # create a couchbase instance with name "JobpostingStorage"
        elasticsearch_init("JobPostingStorage")

        # post_run will be run after the create-stack call is started
        post_run do
          region = @options[:region]
          stack_name = @options[:stack_name]
          client = Aws::CloudFormation::Client.new(region: region)
          cfn = Aws::CloudFormation::Resource.new(client: client)

          # wait for the stack to be created
          stack = wait_stack(cfn, stack_name)

          # get couchbase instance IP address
          ipaddr = get_resource(stack, 'ElasticsearchJobPostingStoragePrivateIpAddress')

          # create a DNS record in route53 for the couchbase instance
          upsert_dns_record(
            zone_name: 'enjapan.local.',
            record_name: "elasticsearch.#{stack_name}.enjapan.local.",
            type: 'A',
            values: [ipaddr]
          )
        end

      end
    end
  end
end
