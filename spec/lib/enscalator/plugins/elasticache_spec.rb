require 'spec_helper'

describe Enscalator::Plugins::ElastiCache do

  let(:app_name) { 'el_cluster_test' }
  let(:description) { 'This is test template for elasticache cluster' }

  describe '#init_cluster_resources' do
    let(:cache_node_type) { 'cache.t2.medium' }
    context 'when invoked with default parameters' do
      let(:template_fixture) do
        el_test_app_name = app_name
        el_test_description = description
        el_test_template_name = app_name.humanize.delete(' ')
        el_test_cache_node_type = cache_node_type
        gen_richtemplate(el_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = el_test_app_name
          value(Description: el_test_description)
          mock_availability_zones
          init_cluster_resources(el_test_app_name, el_test_cache_node_type)
        end
      end
      let(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }

      it 'generates valid template' do
        elasticache_common_template = template_fixture.new(cmd_opts)
        dict = elasticache_common_template.instance_variable_get(:@dict)
        expect(dict.key?(:Resources)).to be_truthy
        resources = dict[:Resources]

        # TODO: add more tests for values in each resource group

        # subnet group
        expect(resources.key?("#{app_name}ElasticacheSubnetGroup")).to be_truthy
        subnet_group = resources["#{app_name}ElasticacheSubnetGroup"]
        expect(subnet_group[:Type]).to eq('AWS::ElastiCache::SubnetGroup')

        # security group
        expect(resources.key?("#{app_name}RedisSecurityGroup")).to be_truthy
        security_group = resources["#{app_name}RedisSecurityGroup"]
        expect(security_group[:Type]).to eq('AWS::EC2::SecurityGroup')

        # redis parameter group
        expect(resources.key?("#{app_name}RedisParameterGroup")).to be_truthy
        parameter_group = resources["#{app_name}RedisParameterGroup"]
        expect(parameter_group[:Type]).to eq('AWS::ElastiCache::ParameterGroup')
      end
    end

    context 'when invoked with custom parameters' do
      let(:template_fixture) do
        el_test_app_name = app_name
        el_test_description = description
        el_test_template_name = app_name.humanize.delete(' ')
        el_test_cache_node_type = cache_node_type
        gen_richtemplate(el_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = el_test_app_name
          value(Description: el_test_description)
          mock_availability_zones
          init_cluster_resources(el_test_app_name, el_test_cache_node_type)
        end
      end
      let(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }
      it 'generates valid template with values corresponding to given parameters' do
        elasticache_common_template = template_fixture.new(cmd_opts)
        dict = elasticache_common_template.instance_variable_get(:@dict)
        expect(dict.key?(:Resources)).to be_truthy
        resources = dict[:Resources]
        parameter_group = resources["#{app_name}RedisParameterGroup"]
        expected_reserved_mem =
          Enscalator::InstanceType.elasticache_instance_type.max_memory(cache_node_type) / 2
        expect(parameter_group[:Properties][:Properties][:'reserved-memory']).to eq(expected_reserved_mem)
      end
    end
  end

  describe '#elasticache_cluster_init' do
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
      let(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }

      it 'generates valid template' do
        elasticache_cluster_template = template_fixture.new(cmd_opts)
        dict = elasticache_cluster_template.instance_variable_get(:@dict)
        expect(dict[:Description]).to eq(description)
        expect(dict.key?(:Resources)).to be_truthy
        resources = dict[:Resources]

        # redis cluster
        expect(resources.key?("#{app_name}RedisCluster")).to be_truthy
        redis_test_cluster = resources["#{app_name}RedisCluster"]
        expect(redis_test_cluster[:Type]).to eq('AWS::ElastiCache::CacheCluster')
      end
    end
  end
end
