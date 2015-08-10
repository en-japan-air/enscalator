require 'spec_helper'

# Testing for public interfaces
describe 'Enscalator::Route53.create_healthcheck' do

  let(:app_name) { 'route53_test' }
  let(:description) { 'This is a template for route53 entries' }

  context 'when invoked with default parameters and fqdn' do

    let(:template_fixture_default) {
      route53_test_app_name = app_name
      route53_test_description = description
      gen_richtemplate(Enscalator::EnAppTemplateDSL) do
        @app_name = route53_test_app_name
        value(Description: route53_test_description)
        mock_availability_zones
      end
    }

    it do
      Route53TestDefault = template_fixture_default
      cmd_opts = default_cmd_opts(Route53TestDefault.name, Route53TestDefault.name.underscore)
      route53_template = Route53TestDefault.new(cmd_opts)

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
end