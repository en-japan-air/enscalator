module Enscalator

  # Collection of methods to work with Route53
  module Route53
    include Enscalator::Helpers

    # Cloudformation template DSL

    # Valid types for Route53 healthcheck
    HealthCheckType = %w{HTTP HTTPS HTTP_STR_MATCH HTTPS_STR_MATCH TCP}

    # Create new Route 53 record set
    #
    def create_single_dns_record(app_name,
                                 stack_name)
      resource "#{app_name}Hostname",
               Type: 'AWS::Route53::RecordSet',
               Properties: {
                 Name: %W{fumanbatch #{public_hosted_zone}}.join('.'),
                 HostedZoneName: public_hosted_zone,
                 Comment: 'A record for fumanbatch',
                 TTL: 300,
                 Type: 'A',
                 ResourceRecords: [
                   ref("#{app_name}PublicIpAddress",)
                 ]
               }
    end

    def create_multiple_dns_records(app_name)
    end

    def create_healthcheck(app_name,
                           stack_name,
                           fqdn: nil,
                           ip_address: nil,
                           port: 80,
                           type: 'HTTP',
                           resource_path: '/',
                           request_interval: 30,
                           failure_threshold: 3,
                           tags: [])
      fail("Route53 healthcheck type can only be one of the following: #{HealthCheckType.join(',')}") unless HealthCheckType.include?(type)
      fail("Route53 healthcheck requires either fqdn or ip address") if [fqdn, ip_address].compact.empty?

      properties = {
        HealthCheckConfig: {
          IPAddress: ip_address,
          FullyQualifiedDomainName: fqdn,
          Port: port,
          Type: type,
          ResourcePath: resource_path,
          RequestInterval: request_interval,
          FailureThreshold: failure_threshold
        }
      }

      properties[:HealthCheckTags] = [
        {
          Key: 'Application',
          Value: app_name
        },
        {
          Key: 'Stack',
          Value: stack_name
        }
      ]

      properties[:HealthCheckTags].concat(tags) if tags && !tags.empty?

      resource "#{app_name}Healthcheck",
               Type: 'AWS::Route53::HealthCheck',
               Properties: properties
    end

    # API calls

    # Get existing DNS records
    #
    # @param [String] zone_name name of the hosted zone
    def get_dns_records(zone_name: nil)
      client = route53_client
      zone = client.list_hosted_zones[:hosted_zones].select { |x| x.name == zone_name }.first
      records = client.list_resource_record_sets(hosted_zone_id: zone.id)
      records.values.flatten.map { |x|
        {
          name: x.name,
          type: x.type,
          records: x.resource_records.map(&:value)
        } if x.is_a?(Aws::Structure)
      }.compact
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
      zone = client.list_hosted_zones[:hosted_zones].select { |x| x.name == zone_name }.first

      record_tokens = [].concat([record_name.gsub(zone_name, ''), region])
      record_tokens << suffix if suffix && !suffix.empty?
      record_name = [record_tokens.join, zone_name].join('.')

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
                resource_records: values.map { |x| {value: x} },
                ttl: ttl
              }
            }
          ]
        }
      )
    end

  end # module Route53
end # module Enscalator
