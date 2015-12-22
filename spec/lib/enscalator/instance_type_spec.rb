require 'spec_helper'

describe Enscalator::InstanceType do
  it 'provides EC2 instance type' do
    ec2_instance_type = described_class.ec2_instance_type
    expect(ec2_instance_type.class).to be(Enscalator::InstanceType::EC2)
    ec2_instance_type.current_generation.values.flatten.each { |cg| assert_ec2_instance_type(cg) }
    ec2_instance_type.previous_generation.values.flatten.each { |pg| assert_ec2_instance_type(pg) }
  end

  it 'provides RDS instance type' do
    rds_instance_type = described_class.rds_instance_type
    expect(rds_instance_type.class).to be(Enscalator::InstanceType::RDS)
    rds_instance_type.current_generation.values.flatten.each { |cg| assert_rds_instance_type(cg) }
    rds_instance_type.previous_generation.values.flatten.each { |pg| assert_rds_instance_type(pg) }
  end

  it 'provides ElasticCache instance type' do
    el_cache_instance_type = described_class.elastic_cache_instance_type
    expect(el_cache_instance_type.class).to be(Enscalator::InstanceType::ElasticCache)
    el_cache_instance_type.current_generation.values.flatten.each { |cg| assert_el_cache_instance_type(cg) }
    el_cache_instance_type.previous_generation.values.flatten.each { |pg| assert_el_cache_instance_type(pg) }
  end

  describe Enscalator::InstanceType::AwsInstance do
    it 'creates instance using constructor with provided values' do
      test_current_gen = { general: %w(gen1.small gen2.big) }
      test_previous_gen = { micro: %w(micro1.small micro2.supersmall) }
      instance = described_class.new(test_current_gen, test_previous_gen)
      expect(instance.current_generation).to be(test_current_gen)
      expect(instance.previous_generation).to be(test_previous_gen)
    end

    it 'creates instance using constructor defaults' do
      instance = described_class.new
      expect(instance.current_generation).to be_empty
      expect(instance.previous_generation).to be_empty
    end

    it 'verifies if given instance type is within given range' do
      test_current_gen = { general: %w(gen1.small gen2.big) }
      instance = described_class.new(test_current_gen)
      expect(instance.supported?(test_current_gen.values.flatten.first)).to be(true)
      expect(instance.supported?('false_type')).to be(false)
    end

    it 'checks if given instance type is obsolete (previous generation)' do
      test_current_gen = { general: %w(gen1.fast gen2.big) }
      test_previous_gen = { micro: %w(micro1.slow) }
      instance = described_class.new(test_current_gen, test_previous_gen)
      expect(instance.obsolete?('micro1.slow')).to be(true)
      expect(instance.obsolete?('gen1.fast')).to be(false)
      expect(instance.obsolete?('false_type')).to be(false)
    end

    it 'returns allowed values for current generation instance types' do
      test_current_gen = { general: %w(gen1.fast gen2.big) }
      test_previous_gen = { micro: %w(micro1.slow) }
      instance = described_class.new(test_current_gen, test_previous_gen)
      expect(instance.allowed_values('gen1.fast')).to include(*test_current_gen.values.flatten)
      expect(instance.allowed_values('gen1.fast')).not_to include(*test_previous_gen.values.flatten)
    end

    it 'returns allowed values for previous generation instance types' do
      test_current_gen = { general: %w(gen1.fast gen2.big) }
      test_previous_gen = { micro: %w(micro1.slow) }
      instance = described_class.new(test_current_gen, test_previous_gen)
      expect(instance.allowed_values('micro1.slow')).to include(*test_previous_gen.values.flatten)
      expect(instance.allowed_values('micro1.slow')).not_to include(*test_current_gen.values.flatten)
    end

    it 'returns empty array for allowed values if instance type is not supported' do
      test_current_gen = { general: %w(gen1.fast gen2.big) }
      test_previous_gen = { micro: %w(micro1.slow) }
      instance = described_class.new(test_current_gen, test_previous_gen)
      expect(instance.allowed_values('superbig10.superfast')).to eq([])
      expect(instance.allowed_values('micro1.slow')).not_to eq([])
    end
  end

  describe Enscalator::InstanceType::EC2 do
    it 'creates new EC2 instance type' do
      ec2 = described_class.new
      common_entries = [:general_purpose, :compute_optimized, :memory_optimized, :gpu]
      ec2_current_families = common_entries.dup.concat([:high_io_optimized, :dense_storage_optimized])
      ec2_previous_families = common_entries.dup.concat([:storage_optimized, :micro])
      expect(ec2.current_generation.keys).to include(*ec2_current_families)
      expect(ec2.previous_generation.keys).to include(*ec2_previous_families)
    end
  end

  describe Enscalator::InstanceType::RDS do
    it 'creates new RDS instance type' do
      rds = described_class.new
      common_entries = [:standard, :memory_optimized]
      rds_current_families = common_entries.dup.concat([:burstable_performance])
      rds_previous_families = common_entries.dup.concat([:micro])
      expect(rds.current_generation.keys).to include(*rds_current_families)
      expect(rds.previous_generation.keys).to include(*rds_previous_families)
    end
  end

  describe Enscalator::InstanceType::ElasticCache do
    it 'creates new ElasticCache instance type' do
      el_cache = described_class.new
      common_entries = [:standard, :memory_optimized]
      el_cache_current_families = common_entries.dup
      el_cache_previous_families = common_entries.dup.concat([:compute_optimized, :micro])
      expect(el_cache.current_generation.keys).to include(*el_cache_current_families)
      expect(el_cache.previous_generation.keys).to include(*el_cache_previous_families)
    end

    describe '#max_memory' do
      let(:el_cache) { described_class.new }
      context 'when instance type is supported' do
        it 'returns maximum available memory for given instance type' do
          expect(el_cache.max_memory('cache.t1.micro')).to eq(142_606_336)
        end
      end

      context 'when instance type is not supported' do
        it 'raises error' do
          expect { el_cache.max_memory('failure') }.to raise_exception KeyError
        end
      end
    end
  end
end
