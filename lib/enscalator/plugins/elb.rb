module Enscalator
  module Plugins
    # Internet facing ELB instance
    module Elb
      # Create new ELB instance
      #
      # @param [String, Hash] elb_name ELB instance name - can be either String or Fn::Join
      # @param [Integer] web_server_port application port to which ELB redirects traffic
      # @param [String] zone_name zone name attached to the vpc
      # @return [String] ELB resource name
      def elb_init(elb_name: join('-', aws_stack_name, 'elb'),
                   web_server_port: 9000,
                   health_check_path: '/',
                   zone_name: nil,
                   dns_record_name: "elb.#{stack_name.dasherize}.#{zone_name}",
                   instances: [],
                   ssl: false,
                   internal: true)

        elb_resource_name = 'LoadBalancer'

        parameter 'WebServerPort',
                  Description: 'TCP/IP Port for the web service',
                  Default: web_server_port,
                  Type: 'Number',
                  MinValue: '0',
                  MaxValue: '65535',
                  ConstraintDescription: 'must be an integer between 0 and 65535.'

        security_group_vpc 'ELBSecurityGroup',
                           'Security group of the application servers',
                           ref('VpcId'),
                           security_group_ingress: [
                             {
                               IpProtocol: 'tcp',
                               FromPort: '0',
                               ToPort: '65535',
                               CidrIp: '10.0.0.0/8'
                             }
                           ] + (internal ? [] : [
                             {
                               IpProtocol: 'tcp',
                               FromPort: '80',
                               ToPort: '80',
                               CidrIp: '0.0.0.0/0'
                             },
                             {
                               IpProtocol: 'tcp',
                               FromPort: '443',
                               ToPort: '443',
                               CidrIp: '0.0.0.0/0'
                             },
                             {
                               IpProtocol: 'tcp',
                               FromPort: '465',
                               ToPort: '465',
                               CidrIp: '0.0.0.0/0'
                             }
                           ]),
                           tags: {
                             Name: join('-', aws_stack_name, 'app', 'sg'),
                             Application: aws_stack_name
                           }

        if ssl
          parameter 'SSLCertificateId',
                    Description: 'Id of the SSL certificate (iam-servercertgetattributes -s certname)',
                    Type: 'String',
                    ConstraintDescription: 'must be a string'
        end

        properties = {
          LoadBalancerName: elb_name,
          Listeners: [
            {
              LoadBalancerPort: '80',
              InstancePort: ref('WebServerPort'),
              Protocol: 'HTTP'
            }
          ] + (ssl == false ? [] : [
            { LoadBalancerPort: '443',
              InstancePort: ref('WebServerPort'),
              SSLCertificateId: ref('SSLCertificateId'),
              Protocol: 'HTTPS' }
          ]),
          HealthCheck: {
            Target: join('', 'HTTP:', ref_web_server_port, health_check_path),
            HealthyThreshold: '3',
            UnhealthyThreshold: '5',
            Interval: '30',
            Timeout: '5'
          },
          SecurityGroups: [ref('ELBSecurityGroup')],
          Subnets: internal ? ref_application_subnets : public_subnets,
          Tags: [
            {
              Key: 'Name',
              Value: elb_name
            },
            {
              Key: 'Application',
              Value: aws_stack_name
            },
            {
              Key: 'Network',
              Value: (internal ? 'Private' : 'Public')
            }
          ]
        }

        properties[:Scheme] = 'internal' if internal
        properties[:Instances] = instances if instances && !instances.empty?

        resource elb_resource_name,
                 Type: 'AWS::ElasticLoadBalancing::LoadBalancer',
                 Properties: properties

        # use alias target to create proper cloudformation template for Route53 side of elb configuration
        alias_target = {
          HostedZoneId: get_att(elb_resource_name, 'CanonicalHostedZoneNameID'),
          DNSName: get_att(elb_resource_name, 'CanonicalHostedZoneName')
        }

        create_single_dns_record(nil,
                                 stack_name,
                                 zone_name,
                                 dns_record_name,
                                 alias_target: alias_target)

        output "#{elb_resource_name}DNSName",
               Description: 'LoadBalancer DNS Name',
               Value: get_att(elb_resource_name, 'DNSName')

        # return resource name
        elb_resource_name
      end
    end # module Elb
  end # module Plugins
end # module Enscalator
