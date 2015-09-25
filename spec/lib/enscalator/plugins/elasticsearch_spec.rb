require 'spec_helper'

# Testing for public interfaces
describe 'Enscalator::Plugins::Elasticsearch' do

  describe '#elasticsearch_init' do

    let(:app_name) { 'es_test' }
    let(:description) { 'This is test template for elasticsearch' }

    context 'when invoked with default parameters' do

      let(:template_fixture) {
        es_test_app_name = app_name
        es_test_description = description
        es_test_template_name = app_name.humanize.delete(' ')
        gen_richtemplate(es_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [Enscalator::Plugins::Elasticsearch]) do
          @app_name = es_test_app_name
          value(Description: es_test_description)
          mock_availability_zones
          elasticsearch_init(es_test_app_name)
        end
      }

      it 'should create mapping template for Elasticsearch' do
        VCR.use_cassette 'elasticsearch_init_mapping_in_template', allow_playback_repeats: true do
          cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
          elasticsearch_template = template_fixture.new(cmd_opts)
          dict = elasticsearch_template.instance_variable_get(:@dict)

          mapping_under_test = dict[:Mappings]['AWSElasticsearchAMI']
          assert_mapping mapping_under_test
          resource_under_test = dict[:Resources]
          expect(resource_under_test.keys).to include("Elasticsearch#{app_name}")
        end
      end
    end

    context 'when properties parameter is set to given value' do

      let(:template_properties) {
        {
          Tags: [
            {
              Key: 'TestKey',
              Value: 'TestValue'
            }
          ]
        }
      }

      let(:template_fixture_with_props) {
        es_test_app_name = app_name
        es_test_description = description
        es_test_template_name = app_name.humanize.delete(' ')
        es_test_properties = template_properties
        gen_richtemplate(es_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [Enscalator::Plugins::Elasticsearch]) do
          @app_name = es_test_app_name
          value(Description: es_test_description)
          mock_availability_zones
          elasticsearch_init(es_test_app_name,
                             properties: es_test_properties)
        end
      }

      it 'should properly combine tags from both plugin and template' do
        VCR.use_cassette 'elasticsearch_template_and_plugin_with_tags' do
          cmd_opts = default_cmd_opts(template_fixture_with_props.name,
                                      template_fixture_with_props.name.underscore)
          elasticsearch_tags_template = template_fixture_with_props.new(cmd_opts)
          dict = elasticsearch_tags_template.instance_variable_get(:@dict)
          tags = dict[:Resources]["Elasticsearch#{app_name}"][:Properties][:Tags]
          keys = tags.map { |t| t[:Key] }
          expect(keys).to include(*%w{TestKey Version ClusterName Name})
          expect(tags.select { |t| t[:Key] == 'TestKey' }.first[:Value]).to eq('TestValue')
        end
      end

    end

  end
end

describe 'Enscalator::Plugins::Elasticsearch' do

  describe '#get_mapping' do

    context 'when invoked with default parameters' do
      it 'should return mapping for amd64 and ebs instances' do
        VCR.use_cassette 'elasticsearch_mapping', allow_playback_repeats: true do
          mapping = Enscalator::Plugins::Elasticsearch.get_mapping
          assert_mapping(mapping)
        end
      end
    end

    context 'when invoked with custom parameters' do
      it 'should return mapping corresponding to them' do
        VCR.use_cassette 'elasticsearch_mapping', allow_playback_repeats: true do
          mapping = Enscalator::Plugins::Elasticsearch.get_mapping(storage: :'instance-store', arch: :i386)
          assert_mapping(mapping, fields: ['pv'])
        end
      end
    end
  end

end

describe 'Enscalator::Plugins::Elasticsearch' do

  describe '#get_release_version' do

    context 'when Elasticsearch version string used for mapping' do
      it {
        VCR.use_cassette 'elasticsearch_version_string', allow_playback_repeats: true do
          version = Enscalator::Plugins::Elasticsearch.get_release_version
          expect(version.split('.').size).to eq(3)
        end
      }
    end

  end

end

# Tests for internal private methods
describe Enscalator::Plugins::Elasticsearch, 'class << self' do

  describe '#fetch_mapping' do
    it 'should fetch mapping for the most recent version' do
      VCR.use_cassette 'elasticsearch_most_recent_version_mapping' do
        mapping = Enscalator::Plugins::Elasticsearch.send(:fetch_mapping, :ebs, :amd64)
        assert_mapping(mapping)
      end
    end
  end

  describe '#fetch_versions' do
    it 'should make request to bitnami release page and parse it to return list of versions' do
      VCR.use_cassette 'elasticsearch_most_recent_version_raw_html' do
        versions = Enscalator::Plugins::Elasticsearch.send(:fetch_versions)
        expect(versions.sample).to be_instance_of(Struct::ElasticSearch)
      end
    end
  end

  describe '#parse_versions' do

    it 'should parse raw version string' do
      test_entry = [%w{elasticsearch-1.4.4-0-amiubuntu-x64?region=us-east-1 ami-96a7f4fe}].to_h
      parsed_entry = Enscalator::Plugins::Elasticsearch.send(:parse_versions, test_entry).first
      expect(parsed_entry.name).to eq('elasticsearch')
      expect(parsed_entry.version).to be_instance_of(Semantic::Version)
      expect(parsed_entry.version).to eq(Semantic::Version.new('1.4.4-0'))
      expect(parsed_entry.baseos).to eq('ubuntu')
      expect(parsed_entry.root_storage).to eq(:'instance-store')
      expect(parsed_entry.arch).to eq(:amd64)
      expect(parsed_entry.region).to eq('us-east-1')
      expect(parsed_entry.ami).to eq('ami-96a7f4fe')
      assert_ami(parsed_entry.ami)
      expect(parsed_entry.virtualization).to eq(:pv)
    end

  end

  describe '#fix_entry' do

    it 'should format raw version string removing non-relevant tokens' do
      test_str = 'elasticsearch-1.4.4-0-amiubuntu-x64-hvm-ebs'
      version_str = Enscalator::Plugins::Elasticsearch.send(:fix_entry, test_str)
      expect(version_str).to match('elasticsearch-1.4.4=0-ubuntu-x64-hvm-ebs')
    end

    it 'should return original string if re-formatting wasn\'t possible' do
      test_str = 'elasticsearch-1.4.4-ebs'
      version_str = Enscalator::Plugins::Elasticsearch.send(:fix_entry, test_str)
      expect(version_str).to match(test_str)
    end

  end

end
