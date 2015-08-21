require 'spec_helper'

describe 'Enscalator::Plugins::Couchbase.couchbase_init' do

  let(:app_name) { 'couchbase_test' }
  let(:description) { 'This is test template for couchbase' }
  let(:bucket) { 'test_bucket' }

  context 'when invoked with default parameters' do

    let(:template_fixture) do
      cb_test_app_name = app_name
      cb_test_description = description
      cb_test_template_name = app_name.humanize.delete(' ')
      cb_test_bucket = bucket
      gen_richtemplate(cb_test_template_name,
                       Enscalator::EnAppTemplateDSL,
                       [Enscalator::Plugins::Couchbase]) do
        @app_name = cb_test_app_name
        value(Description: cb_test_description)
        mock_availability_zones
        couchbase_init(cb_test_app_name, bucket: cb_test_bucket)
      end
    end

    it 'should return template with valid mapping for Couchbase' do
      cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
      cb_template = template_fixture.new(cmd_opts)
      dict = cb_template.instance_variable_get(:@dict)
      mapping_under_test = dict[:Mappings]['AWSCouchbaseAMI']
      assert_mapping(mapping_under_test, fields: AWS_VIRTUALIZATION.values)
      resource_under_test = dict[:Resources]
      expect(resource_under_test.keys).to include("Couchbase#{app_name}")
    end

  end

  context 'when bucket name is not provided' do

    let(:template_nobucket_fixture) do
      cb_test_app_name = app_name
      cb_test_description = description
      cb_test_template_name = app_name.humanize.delete(' ')
      cb_test_bucket = nil
      gen_richtemplate(cb_test_template_name,
                       Enscalator::EnAppTemplateDSL,
                       [Enscalator::Plugins::Couchbase]) do
        @app_name = cb_test_app_name
        value(Description: cb_test_description)
        mock_availability_zones
        couchbase_init(cb_test_app_name, bucket: cb_test_bucket)
      end
    end

    it 'should raise exception' do
      cmd_opts = default_cmd_opts(template_nobucket_fixture.name,
                                  template_nobucket_fixture.name.underscore)
      expect { template_nobucket_fixture.new(cmd_opts) }.to raise_exception RuntimeError
    end

  end
end