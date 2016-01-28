require 'spec_helper'

describe Enscalator::Plugins::ElastiCache do
  describe '#elasticache_cluster_init' do
    let(:app_name) { 'el_cluster_test' }
    let(:description) { 'This is test template for elasticache cluster' }

    context 'when invoked with default parameters' do
      let(:template_fixture) do
        es_test_app_name = app_name
        es_test_description = description
        es_test_template_name = app_name.humanize.delete(' ')
        gen_richtemplate(es_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = es_test_app_name
          value(Description: es_test_description)
          mock_availability_zones
          elasticache_cluster_init(es_test_app_name)
        end
      end

      it 'generates valid template' do
        cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
        elasticache_cluster_template = template_fixture.new(cmd_opts)
        dict = elasticache_cluster_template.instance_variable_get(:@dict)
        expect(dict[:Description]).to eq(description)

        # all resources
        expect(dict.key?(:Resources)).to be_truthy
        resources = dict[:Resources]

        # TODO: move tests for common resources to its own example group

        # subnet group
        expect(resources.key?("#{app_name}ElasticacheSubnetGroup")).to be_truthy
        subnet_group = resources["#{app_name}ElasticacheSubnetGroup"]
        # TODO: add more tests for generated values
        expect(subnet_group[:Type]).to eq('AWS::ElastiCache::SubnetGroup')

        # security group
        expect(resources.key?("#{app_name}RedisSecurityGroup")).to be_truthy
        security_group = resources["#{app_name}RedisSecurityGroup"]
        # TODO: add more tests for generated values
        expect(security_group[:Type]).to eq('AWS::EC2::SecurityGroup')

        # redis parameter group
        expect(resources.key?("#{app_name}RedisParameterGroup")).to be_truthy
        parameter_group = resources["#{app_name}RedisParameterGroup"]
        # TODO: add more tests for generated values
        expect(parameter_group[:Type]).to eq('AWS::ElastiCache::ParameterGroup')

        # redis cluster
        expect(resources.key?("#{app_name}RedisCluster")).to be_truthy
        redis_test_cluster = resources["#{app_name}RedisCluster"]
        expect(redis_test_cluster[:Type]).to eq('AWS::ElastiCache::CacheCluster')
      end
    end
  end
end
