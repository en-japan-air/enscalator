require 'spec_helper'

# Tests for public interfaces
describe 'Enscalator::Plugins::Elasticsearch' do
  xit 'should create mapping template for Elasticsearch' do
    pending
    # VCR.use_cassette 'elasticsearch_init_mapping_in_template' do
    # end
  end
end

# Test for internal private methods
describe 'Enscalator::Plugins::Elasticsearch.private_methods' do
  xit 'should fetch mapping for the most recent version' do
    VCR.use_cassette 'elasticsearch_most_recent_version_mapping' do
      mapping = Enscalator::Plugins::Elasticsearch.send(:fetch_mapping)
    end
  end

  it 'should make request to bitnami release page and parse it to return list of versions' do
    VCR.use_cassette 'elasticsearch_most_recent_version_raw_html' do
      testUrl = 'https://bitnami.com/stack/elasticsearch/cloud/amazon'
      versions = Enscalator::Plugins::Elasticsearch.send(:fetch_versions, testUrl)
      expect(versions.sample).to be_instance_of(Struct::Elasicsearch)
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
    expect(parsedEntry.ami).to eq('ami-96a7f4fe')
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
