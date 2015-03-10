# -*- encoding : utf-8 -*-

module Enscalator
  module Route53
    def get_dns_records(zone_name: nil, region: 'us-east-1')
      client = Aws::Route53::Client.new(region: region)
      zone = client.list_hosted_zones[:hosted_zones].select{|x| x.name == zone_name}.first
      records = client.list_resource_record_sets(hosted_zone_id: zone.id)
      records.values.flatten.map{|x| {name: x.name, type: x.type, records: x.resource_records.map(&:value)} if x.is_a?(Aws::Structure)}.compact
    end

    def upsert_dns_record(zone_name: nil, record_name: nil, type: 'A', region: 'us-east-1', values: [])
      client = Aws::Route53::Client.new(region: region)
      zone = client.list_hosted_zones[:hosted_zones].select{|x| x.name == zone_name}.first

      client.change_resource_record_sets(
        hosted_zone_id: zone.id,
        change_batch: {
          comment: "dns record for #{record_name}",
          changes: [
            { 
              action: "UPSERT",
              resource_record_set: {
                name: record_name,
                type: type,
                resource_records: values.map{|x| {value: x}},
                ttl: 300
              }
            }
          ]
        }
      )
    end
  end
end
