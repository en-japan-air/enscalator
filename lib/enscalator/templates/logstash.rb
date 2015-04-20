# encoding: UTF-8

module Enscalator

  # namespace for template collection
  module Templates

    # template for "a better crawler" Enslurp
    class Logstash < Enscalator::EnAppTemplateDSL

      include Enscalator::Helpers
      include Enscalator::Plugins::CoreOS
      include Enscalator::Plugins::Elasticsearch

      # get vpc configuration from already provisioned stack
      pre_run do
        pre_setup stack_name: 'enjapan-vpc',
                  region: @options[:region]
      end

      def tpl
        elasticsearch_init('Logstash', 100)
        core_os_init() # TODO: FIX THIS
      end

      # create necessary records after stack was provisioned
      post_run do
        region = @options[:region]
        stack_name = @options[:stack_name]

        # TODO: refactor this when branch with improved helpers gets merged
        client = Aws::CloudFormation::Client.new(region: region)
        cfn = Aws::CloudFormation::Resource.new(client: client)

        # wait for the stack to be created
        stack = wait_stack(cfn, stack_name)

        # get couchbase instance IP address
        ipaddr = get_resource(stack, 'ElasticsearchLogstashPrivateIpAddress')

        # create a DNS record in route53 for the couchbase instance
        upsert_dns_record(
            zone_name: 'enjapan.prod.',
            record_name: "elasticsearch.#{stack_name}.enjapan.prod.",
            type: 'A',
            values: [ipaddr]
        )
      end

    end # class Logstash
  end # module Templates
end # module Enscalator
