require 'spec_helper'

describe Enscalator::Plugins::RDS do
  let(:db_name) { 'test_db' }
  let(:description) { 'This is test template for rds' }

  context 'when using default parameters' do
    let(:template_fixture) do
      rds_test_db_name = db_name
      rds_test_description = description
      rds_test_template_name = db_name.humanize.delete(' ')
      gen_richtemplate(rds_test_template_name,
                       Enscalator::EnAppTemplateDSL,
                       [Enscalator::Plugins::RDS]) do
        @db_name = rds_test_db_name
        value(Description: rds_test_description)
        mock_availability_zones
        rds_init(rds_test_db_name)
      end
    end

    it 'should create valid template' do
      cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
      rds_template = template_fixture.new(cmd_opts)
      dict = rds_template.instance_variable_get(:@dict)
      params_under_test = dict[:Parameters]
      resources_under_test = dict[:Resources]

      expected_parameters = %w{Name AllocatedStorage
                          StorageType Multizone ParameterGroup
                          InstanceType Username Password}.map { |p| "RDS#{db_name}#{p}" }
      expect(params_under_test.keys).to include(*expected_parameters)

      subnet_res = "RDS#{db_name}SubnetGroup"
      rds_instance_res = "RDS#{db_name}Instance"
      expect(resources_under_test.keys).to include(*[subnet_res, rds_instance_res])
      expect(resources_under_test[rds_instance_res][:Properties].keys).not_to include(:DBSnapshotIdentifier)
      expect(dict[:Outputs].keys).to include("RDS#{db_name}EndpointAddress")
    end
  end

  context 'when properties with custom tags where passed' do
    let(:tags) {
      {
        Tags: [
          Key: 'TestTagKey',
          Value: 'TestTagValue'
        ]
      }
    }

    let(:template_fixture_with_tags) do
      rds_test_db_name = db_name
      rds_test_description = description
      rds_test_tags = tags
      rds_test_template_name = db_name.humanize.delete(' ')
      gen_richtemplate(rds_test_template_name,
                       Enscalator::EnAppTemplateDSL,
                       [Enscalator::Plugins::RDS]) do
        @db_name = rds_test_db_name
        value(Description: rds_test_description)
        mock_availability_zones
        rds_init(rds_test_db_name,
                 properties: rds_test_tags)
      end
    end

    it 'should create valid template with custom tags' do
      cmd_opts = default_cmd_opts(template_fixture_with_tags.name,
                                  template_fixture_with_tags.name.underscore)
      rds_template = template_fixture_with_tags.new(cmd_opts)
      dict = rds_template.instance_variable_get(:@dict)
      tags_under_test = dict[:Resources]["RDS#{db_name}Instance"][:Properties][:Tags]
      expect(tags_under_test).to include(*tags[:Tags])
    end
  end

  context 'when use_snapshot is set to true' do
    let(:template_fixture_with_snapshot) do
      rds_test_db_name = db_name
      rds_test_description = description
      rds_test_template_name = db_name.humanize.delete(' ')
      gen_richtemplate(rds_test_template_name,
                       Enscalator::EnAppTemplateDSL,
                       [Enscalator::Plugins::RDS]) do
        @db_name = rds_test_db_name
        value(Description: rds_test_description)
        mock_availability_zones
        rds_init(rds_test_db_name,
                 use_snapshot: true)
      end
    end

    it 'should create template with DBSnapshotIdentifier instead of DBName' do
      cmd_opts = default_cmd_opts(template_fixture_with_snapshot.name,
                                  template_fixture_with_snapshot.name.underscore)
      rds_template = template_fixture_with_snapshot.new(cmd_opts)
      dict = rds_template.instance_variable_get(:@dict)
      resources_under_test = dict[:Resources]
      rds_resource_props = resources_under_test["RDS#{db_name}Instance"][:Properties]
      expect(rds_resource_props).to include(:DBSnapshotIdentifier)
      expect(rds_resource_props).not_to include(:DBName)
    end
  end

end
