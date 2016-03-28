module Enscalator
  module Plugins
    # Create Route53 resources
    module Route53
      # Valid types for Route53 healthcheck
      HEALTH_CHECK_TYPE = %w(HTTP HTTPS HTTP_STR_MATCH HTTPS_STR_MATCH TCP)

      # Valid types for dns records
      RECORD_TYPE = %w(A AAAA CNAME MX NS PTR SOA SPF SRV TXT)

      # Create Route53 healthcheck for given fqdn/ip address
      #
      # @param [String] app_name application name
      # @param [String] stack_name stack name
      # @param [String] fqdn fully qualified domain name (FQDN)
      # @param [String] ip_address ip address
      # @param [Integer] port number
      # @param [String] type healthcheck type
      # @param [String] resource_path uri path healthcheck backend would query
      # @param [Integer] request_interval query intervals for healthcheck backend
      # @param [Integer] failure_threshold number of accumulated failures to consider endpoint not healthy
      # @param [Array] tags additional tags
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
        unless HEALTH_CHECK_TYPE.include?(type)
          fail("Route53 healthcheck type can only be one of the following: #{HEALTH_CHECK_TYPE.join(',')}")
        end
        fail('Route53 healthcheck requires either fqdn or ip address') unless fqdn || ip_address

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

        properties[:HealthCheckTags].concat(tags) unless tags.blank?

        resource "#{app_name}Healthcheck",
                 Type: 'AWS::Route53::HealthCheck',
                 Properties: properties
      end

      # [RESERVED] Create new hosted zone
      def create_hosted_zone
        fail('method "create_hosted_zone" is not implemented yet')
      end

      # TODO: http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-recordset.html

      # Create new single record set for given hosted zone
      #
      # @param [String] app_name application name
      # @param [String] stack_name stack name
      # @param [String] zone_name hosted zone name
      # @param [String] record_name dns record name
      # @param [Integer] ttl time to live
      # @param [String] type dns record type
      # @param [Hash] healthcheck reference to the healthcheck resource
      # @param [Hash] alias_target alias target
      # @param [Array] resource_records resources associated with record_name
      def create_single_dns_record(app_name,
                                   stack_name,
                                   zone_name,
                                   record_name,
                                   ttl: 300,
                                   type: 'A',
                                   healthcheck: nil,
                                   alias_target: {},
                                   resource_records: [])
        if type && !RECORD_TYPE.include?(type)
          fail("Route53 record type can only be one of the following: #{RECORD_TYPE.join(',')}")
        end
        if healthcheck && (!healthcheck.is_a?(Hash) || !healthcheck.include?(:Ref))
          fail('healthcheck must be a valid cloudformation Ref function')
        end
        if alias_target && (!alias_target.is_a?(Hash))
          fail('AliasTarget must be a Hash')
        end

        name = app_name || stack_name.titleize.remove(/\s/)
        properties = {
          Name: record_name,
          Comment: "#{type} record for #{[app_name, 'in '].join(' ') if app_name}#{stack_name} stack",
          HostedZoneName: zone_name,
          Type: type
        }

        if !alias_target.blank?
          fail('AliasTarget can be created only for A or AAAA type records') unless %w(A AAAA).include?(type)
          unless alias_target.key?(:HostedZoneId) && alias_target.key?(:DNSName)
            fail('AliasTarget must have HostedZoneId and DNSName properties')
          end
          properties[:AliasTarget] = alias_target
        else
          properties[:TTL] = ttl
          properties[:HealthCheckId] = healthcheck if healthcheck
          properties[:ResourceRecords] = resource_records.empty? ? ref("#{app_name}PublicIpAddress") : resource_records
        end

        resource "#{name}Hostname",
                 Type: 'AWS::Route53::RecordSet',
                 Properties: properties
      end

      # [RESERVED] Create multiple record sets for given hosted zone
      def create_multiple_dns_records
        fail('method "create_multiple_dns_records" is not implemented')
      end
    end # module Route53
  end # module Plugins
end # module Enscalator
