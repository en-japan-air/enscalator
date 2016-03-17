require 'spec_helper'

describe Enscalator::Plugins::Elasticache do
  let(:app_name) { 'el_cluster_test' }
  let(:description) { 'This is test template for elasticache cluster' }

  # Test fixture class where plugin methods gets included
  class TestFixture
    include Enscalator::Plugins::Elasticache
  end

  describe '#magic_number' do
    subject(:fixture) { TestFixture.new }
    subject(:digest) { Digest::SHA256.new }
    context 'when input is String' do
      let(:test_str) { ('a'..'z').to_a.shuffle.join }
      it 'its generates magic number right away' do
        expect(fixture.magic_number(test_str)).to eq(digest.hexdigest(test_str))
      end
    end
    context 'when input is Array' do
      let(:test_arr) { [1, 2, 3, 'b', [4, 'c']] }
      it 'converts it to String and then generates magic number' do
        expect(fixture.magic_number(test_arr)).to eq(digest.hexdigest('1&2&3&4&b&c'))
      end
      it 'produce valid magic number regardless of the order' do
        expect(fixture.magic_number(test_arr.shuffle)).to eq(fixture.magic_number(test_arr))
      end
    end
    context 'when input is Hash' do
      let(:test_hash) { { a: { c: 'c' }, b: { b: 'b', d: 'd' } } }
      let(:test_hash_reordered) { { b: { d: 'd', b: 'b' }, a: { c: 'c' } } }
      it 'flattens it and then generates magic number' do
        expect(fixture.magic_number(test_hash)).to eq(digest.hexdigest('a.c=c&b.b=b&b.d=d'))
      end
      it 'produce valid magic number regardless of the order' do
        expect(fixture.magic_number(test_hash)).to eq(fixture.magic_number(test_hash_reordered))
      end
    end
  end

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
        expect(dict).to have_key(:Resources)
        resources = dict[:Resources]

        # TODO: add more tests for values in each resource group

        # subnet group
        expect(resources).to have_key("#{app_name}ElasticacheSubnetGroup")
        subnet_group = resources["#{app_name}ElasticacheSubnetGroup"]
        expect(subnet_group[:Type]).to eq('AWS::ElastiCache::SubnetGroup')

        # security group
        expect(resources).to have_key("#{app_name}RedisSecurityGroup")
        security_group = resources["#{app_name}RedisSecurityGroup"]
        expect(security_group[:Type]).to eq('AWS::EC2::SecurityGroup')

        # redis parameter group
        # have to get resource key with regex, using its known non-dynamic part
        parameter_group_name = resources.keys.detect { |k| k.to_s =~ /#{app_name}RedisParameterGroup/ }
        expect(parameter_group_name).not_to be_nil
        parameter_group = resources[parameter_group_name]
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
        parameter_group_name = resources.keys.detect { |k| k.to_s =~ /#{app_name}RedisParameterGroup/ }
        parameter_group = resources[parameter_group_name]
        expected_reserved_mem =
          Enscalator::InstanceType.elasticache_instance_type.max_memory(cache_node_type) / 2
        expect(parameter_group[:Properties][:Properties][:'reserved-memory']).to eq(expected_reserved_mem)
      end
    end
  end

  describe '#elasticache_cluster_init' do
    context 'when invoked with default parameters' do
      let(:template_fixture) do
        el_test_app_name = app_name
        el_test_description = description
        el_test_template_name = app_name.humanize.delete(' ')
        gen_richtemplate(el_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = el_test_app_name
          value(Description: el_test_description)
          mock_availability_zones
          elasticache_cluster_init(el_test_app_name)
        end
      end
      let(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }

      it 'generates valid template' do
        elasticache_cluster_template = template_fixture.new(cmd_opts)
        dict = elasticache_cluster_template.instance_variable_get(:@dict)
        expect(dict[:Description]).to eq(description)
        expect(dict).to have_key(:Resources)
        resources = dict[:Resources]

        # redis cluster
        expect(resources.key?("#{app_name}RedisCluster")).to be_truthy
        redis_test_cluster = resources["#{app_name}RedisCluster"]
        expect(redis_test_cluster[:Type]).to eq('AWS::ElastiCache::CacheCluster')
      end
    end
  end

  describe '#elasticache_repl_group_init' do
    context 'when invoked with default parameters' do
      let(:template_fixture) do
        el_test_app_name = app_name
        el_test_description = description
        el_test_template_name = app_name.humanize.delete(' ')
        gen_richtemplate(el_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = el_test_app_name
          value(Description: el_test_description)
          mock_availability_zones
          elasticache_repl_group_init(el_test_app_name)
        end
      end
      let(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }

      it 'generates valid template' do
        elasticache_cluster_template = template_fixture.new(cmd_opts)
        dict = elasticache_cluster_template.instance_variable_get(:@dict)
        expect(dict[:Description]).to eq(description)
        expect(dict).to have_key(:Resources)
        resources = dict[:Resources]

        # redis replication group
        redis_repl_group = resources["#{app_name}RedisReplicationGroup"]
        expect(redis_repl_group[:Type]).to eq('AWS::ElastiCache::ReplicationGroup')
        expect(redis_repl_group[:Properties][:Engine]).to eq('redis')
        expect(redis_repl_group[:Properties][:ReplicationGroupDescription]).to include(app_name)
        expect(redis_repl_group[:Properties][:AutomaticFailoverEnabled]).to eq(true.to_s)
        expect(redis_repl_group[:Properties][:NumCacheClusters]).to be >= 2
        expect(redis_repl_group[:Properties][:CacheNodeType]).to satisfy do |value|
          %w(t1 t2).map { |t| value.include?(t) }.uniq.include?(false)
        end
      end
    end

    context 'when invoked with not supported cache_node_type' do
      let(:template_fixture) do
        el_test_app_name = app_name
        el_test_description = description
        el_test_template_name = app_name.humanize.delete(' ')
        gen_richtemplate(el_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = el_test_app_name
          value(Description: el_test_description)
          mock_availability_zones
          elasticache_repl_group_init(el_test_app_name, cache_node_type: 'cache.t1.micro')
        end
      end
      let(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }
      it 'raises error' do
        expect { template_fixture.new(cmd_opts) }.to raise_error
      end
    end

    context 'when invoked with num_cache_clusters < 2' do
      let(:template_fixture) do
        el_test_app_name = app_name
        el_test_description = description
        el_test_template_name = app_name.humanize.delete(' ')
        gen_richtemplate(el_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = el_test_app_name
          value(Description: el_test_description)
          mock_availability_zones
          elasticache_repl_group_init(el_test_app_name, num_cache_clusters: 1)
        end
      end
      let(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }
      it 'raises error' do
        expect { template_fixture.new(cmd_opts) }.to raise_error
      end
    end
  end
end
