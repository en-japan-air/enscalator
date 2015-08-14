require 'spec_helper'

describe 'Enscalator::Route53.create_single_dns_record' do

  let(:app_name) { 'route53_dns_record_test' }
  let(:description) { 'This is a template for route53 test dns records' }
  let(:dns_record_template_fixture_default) {
    route53_test_app_name = app_name
    route53_test_description = description
    gen_richtemplate(Enscalator::EnAppTemplateDSL) do
      @app_name = route53_test_app_name
      value(Description: route53_test_description)
      mock_availability_zones
    end
  }

  context 'when invoked with default parameters' do

    it 'should generate resource template for single dns A record entry' do
      Route53TestDefaultDNSRecord = dns_record_template_fixture_default
      cmd_opts = default_cmd_opts(Route53TestDefaultDNSRecord.name,
                                  Route53TestDefaultDNSRecord.name.underscore)
                   .merge({hosted_zone: 'private.enjapan.test'})
      route53_template = Route53TestDefaultDNSRecord.new(cmd_opts)

      test_record_name = 'test-entry-default'
      route53_template.create_single_dns_record(app_name,
                                                cmd_opts[:stack_name],
                                                cmd_opts[:hosted_zone],
                                                test_record_name)
      dict = route53_template.instance_variable_get(:@dict)
      expect(dict[:Description]).to eq(description)
      expect(dict[:Resources]["#{app_name}Hostname"].empty?).to be_falsey
      test_resources = dict[:Resources]["#{app_name}Hostname"]
      expect(test_resources[:Type]).to eq('AWS::Route53::RecordSet')
      properties = test_resources[:Properties]
      expect(properties[:Name]).to eq(test_record_name)
      expect(properties[:HostedZoneName]).to eq(cmd_opts[:hosted_zone])
      expect(properties[:TTL]).to eq(300)
      expect(properties[:Type]).to eq('A')
      expect(properties[:ResourceRecords]).to eq(ref("#{app_name}PublicIpAddress"))
    end

  end

  context 'when invoked with healthcheck parameter with non-default value' do
    it 'should include valid healthcheck reference in generated template' do
      Route53TestDefaultValidHealthCheck = dns_record_template_fixture_default
      cmd_opts =
        default_cmd_opts(Route53TestDefaultValidHealthCheck.name,
                         Route53TestDefaultValidHealthCheck.name.underscore)
          .merge({hosted_zone: 'private.enjapan.test'})
      route53_template = Route53TestDefaultValidHealthCheck.new(cmd_opts)
      test_record_name = 'test-entry-healthy-default'
      test_healthcheck = "#{app_name}Healthcheck"
      route53_template.create_single_dns_record(app_name,
                                                cmd_opts[:stack_name],
                                                cmd_opts[:hosted_zone],
                                                test_record_name,
                                                healthcheck: ref(test_healthcheck))
      dict = route53_template.instance_variable_get(:@dict)
      test_resources = dict[:Resources]["#{app_name}Hostname"]
      expect(test_resources[:Properties][:HealthCheckId]).to eq(ref(test_healthcheck))
    end

    it 'should raise Runtime exception if its not valid' do
      Route53TestDefaultNonValidHealthCheck = dns_record_template_fixture_default
      cmd_opts =
        default_cmd_opts(Route53TestDefaultNonValidHealthCheck.name,
                         Route53TestDefaultNonValidHealthCheck.name.underscore)
          .merge({hosted_zone: 'private.enjapan.test'})
      route53_template = Route53TestDefaultNonValidHealthCheck.new(cmd_opts)
      test_record_name = 'test-entry-nonhealthy-default'
      expect {
        route53_template.create_single_dns_record(app_name,
                                                  cmd_opts[:stack_name],
                                                  cmd_opts[:hosted_zone],
                                                  test_record_name,
                                                  healthcheck: []) }.to raise_exception(RuntimeError)
    end
  end
end


describe 'Enscalator::Route53.create_healthcheck' do

  let(:app_name) { 'route53_healthcheck_test' }
  let(:description) { 'This is a template for route53 healthcheck test entries' }
  let(:healthcheck_template_fixture_default) {
    route53_test_app_name = app_name
    route53_test_description = description
    gen_richtemplate(Enscalator::EnAppTemplateDSL) do
      @app_name = route53_test_app_name
      value(Description: route53_test_description)
      mock_availability_zones
    end
  }

  context 'when invoked with default parameters and fqdn' do
    it 'should generate valid template with fqdn and empty ip address' do
      Route53TestDefaultFQDN = healthcheck_template_fixture_default
      cmd_opts = default_cmd_opts(Route53TestDefaultFQDN.name,
                                  Route53TestDefaultFQDN.name.underscore)
      route53_template = Route53TestDefaultFQDN.new(cmd_opts)

      test_fqdn = 'somedomain.test.japan.en'
      route53_template.create_healthcheck(app_name,
                                          cmd_opts[:stack_name],
                                          fqdn: test_fqdn)
      dict = route53_template.instance_variable_get(:@dict)
      expect(dict[:Description]).to eq(description)
      expect(dict[:Resources]["#{app_name}Healthcheck"].empty?).to be_falsey
      test_resources = dict[:Resources]["#{app_name}Healthcheck"]
      expect(test_resources[:Type]).to eq('AWS::Route53::HealthCheck')
      config = test_resources[:Properties][:HealthCheckConfig]
      expect(config[:IPAddress]).to be_nil
      expect(config[:FullyQualifiedDomainName]).to eq(test_fqdn)
      tags = test_resources[:Properties][:HealthCheckTags]
      expect(tags).to include({Key: 'Application', Value: app_name}) and
        include({Key: 'Stack', Value: cmd_opts[:stack_name]})
    end
  end

  context 'when invoked with default parameters and ip address' do
    it 'should generate valid template with ip address and without fqdn' do
      Route53TestDefaultIPAddr = healthcheck_template_fixture_default
      cmd_opts = default_cmd_opts(Route53TestDefaultIPAddr.name,
                                  Route53TestDefaultIPAddr.name.underscore)
      route53_template = Route53TestDefaultIPAddr.new(cmd_opts)

      test_ip_addr = '172.0.0.55'
      route53_template.create_healthcheck(app_name,
                                          cmd_opts[:stack_name],
                                          ip_address: test_ip_addr)

      dict = route53_template.instance_variable_get(:@dict)
      expect(dict[:Resources]["#{app_name}Healthcheck"].empty?).to be_falsey
      test_resources = dict[:Resources]["#{app_name}Healthcheck"]
      config = test_resources[:Properties][:HealthCheckConfig]
      expect(config[:FullyQualifiedDomainName]).to be_nil
      expect(config[:IPAddress]).to eq(test_ip_addr)
    end
  end

  context 'when invoked with not supported healthcheck type' do
    it 'should raise Runtime exception' do
      Route53TestNonValidType = healthcheck_template_fixture_default
      cmd_opts = default_cmd_opts(Route53TestNonValidType.name, Route53TestNonValidType.name.underscore)
      route53_template = Route53TestNonValidType.new(cmd_opts)
      test_fqdn = 'nonvalid.type.japan.en'

      expect { route53_template.create_healthcheck(app_name,
                                                   cmd_opts[:stack_name],
                                                   fqdn: test_fqdn,
                                                   type: 'UDP') }.to raise_exception(RuntimeError)
    end
  end
end