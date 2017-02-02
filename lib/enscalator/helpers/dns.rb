module Enscalator
  module Helpers
    module Dns
      # Get existing DNS records
      #
      # @param [String] zone_name name of the hosted zone
      def get_dns_records(zone_name: nil)
        client = route53_client(nil)
        zone = client.list_hosted_zones[:hosted_zones].find { |x| x.name == zone_name }
        records = client.list_resource_record_sets(hosted_zone_id: zone.id)
        records.values.flatten.map do |x|
          {
            name: x.name,
            type: x.type,
            records: x.resource_records.map(&:value)
          } if x.is_a?(Aws::Structure)
        end.compact
      end

      # Create DNS record in given hosted zone
      #
      # @param [String] region aws valid region identifier
      # @param [String] zone_name name of the hosted zone
      # @param [String] record_name name of the dns record
      # @param [String] type record type (NS, MX, CNAME and etc.)
      # @param [Array] values list of record values
      # @param [Integer] ttl time to live
      # @param [String] suffix additional identifier following region
      def upsert_dns_record(region: nil,
                            zone_name: nil,
                            record_name: nil,
                            type: 'A',
                            values: [],
                            ttl: 300,
                            suffix: '')
        client = route53_client(region: region)
        zone = client.list_hosted_zones[:hosted_zones].find { |x| x.name == zone_name }
        record_tokens = [record_name.gsub(zone_name, ''), region]
        record_tokens << suffix if suffix && !suffix.empty?
        record_name = [record_tokens.join, zone_name].join('.')

        client.change_resource_record_sets(
          hosted_zone_id: zone.id,
          change_batch: {
            comment: "dns record for #{record_name}",
            changes: [
              {
                action: 'UPSERT',
                resource_record_set: {
                  name: record_name,
                  type: type,
                  resource_records: values.map { |x| { value: x } },
                  ttl: ttl
                }
              }
            ]
          }
        )
      end
    end
  end
end
