require 'spec_helper'

describe Enscalator::Plugins::Elb, '#elb_init' do
  let(:app_name) { 'elb_test' }
  let(:description) { 'This is test template for elastic load balancer' }

  context 'when invoked with default parameters' do
    let(:template_name) { app_name.humanize.delete(' ') }
    let(:template_fixture) do
      elb_test_app_name = app_name
      elb_test_description = description
      elb_test_template_name = template_name
      gen_richtemplate(elb_test_template_name,
                       Enscalator::EnAppTemplateDSL,
                       [Enscalator::Plugins::Elb]) do
        @app_name = elb_test_app_name
        value(Description: elb_test_description)
        mock_availability_zones
        elb_init
      end
    end

    it 'should generate valid template with default values' do
      cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
      elb_template = template_fixture.new(cmd_opts)
      dict = elb_template.instance_variable_get(:@dict)
      parameters = dict[:Parameters]
      expect(parameters['WebServerPort'][:Default]).to eq(9000)
      resources = dict[:Resources]
      expect(resources['ELBSecurityGroup']).to_not be_nil
      security_group = resources['ELBSecurityGroup']
      expect(security_group[:Type]).to eq('AWS::EC2::SecurityGroup')
      expected_security_ingress = { IpProtocol: 'tcp',
                                    FromPort: '0',
                                    ToPort: '65535',
                                    CidrIp: '10.0.0.0/8' }
      expect(security_group[:Properties][:SecurityGroupIngress]).to include(expected_security_ingress)
      load_balancer = resources['LoadBalancer']
      expect(load_balancer[:Type]).to eq('AWS::ElasticLoadBalancing::LoadBalancer')
      expect(load_balancer[:Properties][:SecurityGroups]).to include({ Ref: 'ELBSecurityGroup' })
      expect(load_balancer[:Properties][:Scheme]).to eq('internal')
    end
  end

  context 'when invoked with parameters' do
    let(:template_name) { app_name.humanize.delete(' ') }
    let(:template_instances) { [ref('TestInstance1'), ref('TestInstance2')] }
    let(:template_fixture) do
      elb_test_app_name = app_name
      elb_test_description = description
      elb_test_template_name = template_name
      elb_test_template_instances = template_instances
      gen_richtemplate(elb_test_template_name,
                       Enscalator::EnAppTemplateDSL,
                       [Enscalator::Plugins::Elb]) do
        @app_name = elb_test_app_name
        value(Description: elb_test_description)
        mock_availability_zones
        class << self
          def public_subnets
            subnets = { a: 'subnet-0123a456b',
                        b: 'subnet-789c1112',
                        c: 'subnet-1314d15e',
                        d: 'subnet-1617f18g',
                        e: 'subnet-1920h21i' }
            availability_zones.map { |suffix, _| subnets[suffix] }
          end
        end
        elb_init(instances: elb_test_template_instances, ssl: true, internal: false)
      end
    end

    it 'should generate valid template using provided values' do
      cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
      elb_template = template_fixture.new(cmd_opts)
      dict = elb_template.instance_variable_get(:@dict)
      resources = dict[:Resources]
      expect(resources['ELBSecurityGroup']).to_not be_nil
      security_group = resources['ELBSecurityGroup']
      security_group_ingress = security_group[:Properties][:SecurityGroupIngress]
      expected_security_ingress = [{ IpProtocol: 'tcp',
                                     FromPort: '0',
                                     ToPort: '65535',
                                     CidrIp: '10.0.0.0/8' },
                                   { IpProtocol: 'tcp',
                                     FromPort: '80',
                                     ToPort: '80',
                                     CidrIp: '0.0.0.0/0' },
                                   { IpProtocol: 'tcp',
                                     FromPort: '443',
                                     ToPort: '443',
                                     CidrIp: '0.0.0.0/0' },
                                   { IpProtocol: 'tcp',
                                     FromPort: '465',
                                     ToPort: '465',
                                     CidrIp: '0.0.0.0/0' }]
      expect(security_group_ingress).to include(*expected_security_ingress)
      elb = resources['LoadBalancer']
      listeners = elb[:Properties][:Listeners]
      expected_listeners = [{
                              LoadBalancerPort: '80',
                              InstancePort: ref('WebServerPort'),
                              Protocol: 'HTTP'
                            },
                            {
                              LoadBalancerPort: '443',
                              InstancePort: ref('WebServerPort'),
                              SSLCertificateId: ref('SSLCertificateId'),
                              Protocol: 'HTTPS'
                            }]
      expect(listeners).to include(*expected_listeners)
      instances = elb[:Properties][:Instances]
      expect(instances).to eq(template_instances)
    end
  end
end