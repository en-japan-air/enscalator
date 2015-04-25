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
      p versions
    end
  end
end
