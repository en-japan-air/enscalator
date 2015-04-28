require 'spec_helper'

# Tests for public interfaces
describe 'Enscalator::Plugins::Elasticsearch' do
  it 'should create mapping template for Elasticsearch' do
    VCR.use_cassette 'elasticsearch_init_mapping_in_template' do
      class ElasticsearchTestTemplate < Enscalator::EnAppTemplateDSL
        include Enscalator::Plugins::Elasticsearch
        define_method :tpl do
          elasticsearch_init('test_server')
        end
      end

      elasticsearch_template = ElasticsearchTestTemplate.new
      dict = elasticsearch_template.instance_variable_get(:@dict)

      mapping_under_test = dict[:Mappings]['AWSElasticsearchAMI']
      assert_mapping mapping_under_test, fields: AWS_VIRTUALIZATION.keys

      resource_under_test = dict[:Resources]
      expect(resource_under_test.keys).to include('Elasticsearchtest_server')
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
    testEntry = [['elasticsearch-1.4.4-0-amiubuntu-x64?region=us-east-1', 'ami-96a7f4fe']].to_h
    parsedEntry = Enscalator::Plugins::Elasticsearch.send(:parse_versions, testEntry).first
    expect(parsedEntry.name).to eq('elasticsearch')
    expect(parsedEntry.version).to be_instance_of(Semantic::Version)
    expect(parsedEntry.version).to eq(Semantic::Version.new('1.4.4-0'))
    expect(parsedEntry.baseos).to eq('ubuntu')
    expect(parsedEntry.root_storage).to eq(:'instance-store')
    expect(parsedEntry.arch).to eq(:amd64)
    expect(parsedEntry.region).to eq('us-east-1')
    expect(parsedEntry.ami).to eq('ami-96a7f4fe')
    assert_ami(parsedEntry.ami)
    expect(parsedEntry.virtualization).to eq(:pv)
  end

  it 'should format raw version string removing non-relevant tokens' do
    testStr = 'elasticsearch-1.4.4-0-amiubuntu-x64-hvm-ebs'
    version_str = Enscalator::Plugins::Elasticsearch.send(:fix_entry, testStr)
    expect(version_str).to match('elasticsearch-1.4.4=0-ubuntu-x64-hvm-ebs')
  end

  it 'should return original string if re-formatting wasn\'t possible' do
    testStr = 'elasticsearch-1.4.4-ebs'
    version_str = Enscalator::Plugins::Elasticsearch.send(:fix_entry, testStr)
    expect(version_str).to match(testStr)
  end
end
