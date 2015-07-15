require 'spec_helper'

# Tests for public interfaces
describe 'Enscalator::Plugins::Elasticsearch' do

  it 'should create mapping template for Elasticsearch' do
    VCR.use_cassette 'elasticsearch_init_mapping_in_template' do
      class ElasticsearchTestTemplate < Enscalator::EnAppTemplateDSL
        include Enscalator::Plugins::Elasticsearch
        define_method :tpl do
          mock_availability_zones
          elasticsearch_init('test_server')
        end
      end

      elasticsearch_template = ElasticsearchTestTemplate.new
      dict = elasticsearch_template.instance_variable_get(:@dict)

      mapping_under_test = dict[:Mappings]['AWSElasticsearchAMI']
      assert_mapping mapping_under_test

      resource_under_test = dict[:Resources]
      expect(resource_under_test.keys).to include('Elasticsearchtest_server')
    end
  end

  it 'should properly combine tags when they supplied in both plugin and template' do
    VCR.use_cassette 'elasticsearch_template_and_plugin_with_tags' do
      class ElasticsearchTestTagsTemplate < Enscalator::EnAppTemplateDSL
        include Enscalator::Plugins::Elasticsearch
        define_method :tpl do
          mock_availability_zones
          elasticsearch_init('test_server',
                             properties: {
                               Tags: [
                                 {
                                   Key: 'TestKey',
                                   Value: 'TestValue'
                                 }
                               ]
                             })
        end
      end

      elasticsearch_tags_template = ElasticsearchTestTagsTemplate.new
      dict = elasticsearch_tags_template.instance_variable_get(:@dict)
      tags = dict[:Resources]['Elasticsearchtest_server'][:Properties][:Tags]
      keys = tags.map { |t| t[:Key] }
      expect(keys).to include(*%w{TestKey Version ClusterName Name})
      expect(tags.select { |t| t[:Key] == 'TestKey' }.first[:Value]).to eq('TestValue')
    end
  end

  it 'should return Elasticsearch version string used for mapping' do
    VCR.use_cassette 'elasticsearch_version_string' do
      version = Enscalator::Plugins::Elasticsearch.get_release_version
      expect(version.split('.').size).to eq(3)
    end
  end

end

# Tests for internal private methods
describe 'Enscalator::Plugins::Elasticsearch.private_methods' do

  it 'should fetch mapping for the most recent version' do
    VCR.use_cassette 'elasticsearch_most_recent_version_mapping' do
      mapping = Enscalator::Plugins::Elasticsearch.send(:fetch_mapping, :ebs, :amd64)
      assert_mapping(mapping)
    end
  end

  it 'should make request to bitnami release page and parse it to return list of versions' do
    VCR.use_cassette 'elasticsearch_most_recent_version_raw_html' do
      versions = Enscalator::Plugins::Elasticsearch.send(:fetch_versions)
      expect(versions.sample).to be_instance_of(Struct::ElasticSearch)
    end
  end

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
