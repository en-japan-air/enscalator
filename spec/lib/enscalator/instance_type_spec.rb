require 'spec_helper'

describe 'Enscalator::InstanceType' do

  it 'should provide EC2 instance type' do
    ec2_instance_type = Enscalator::InstanceType.ec2_instance_type
    expect(ec2_instance_type.class).to be(Enscalator::InstanceType::EC2)
    ec2_instance_type.current_generation.values.flatten.each { |cg| assert_ec2_instance_type(cg) }
    ec2_instance_type.previous_generation.values.flatten.each { |pg| assert_ec2_instance_type(pg) }
  end

  it 'should provide RDS instance type' do
    rds_instance_type = Enscalator::InstanceType.rds_instance_type
    expect(rds_instance_type.class).to be(Enscalator::InstanceType::RDS)
    rds_instance_type.current_generation.values.flatten.each { |cg| assert_rds_instance_type(cg) }
    rds_instance_type.previous_generation.values.flatten.each { |pg| assert_rds_instance_type(pg) }
  end

end

describe 'Enscalator::InstanceType::AwsInstance' do

  it 'should create instance using constructor with provided values' do
    test_current_gen = {general: %w{ gen1.small gen2.big }}
    test_previous_gen = {micro: %w{ micro1.small micro2.supersmall }}
    instance = Enscalator::InstanceType::AwsInstance.new(test_current_gen, test_previous_gen)
    expect(instance.current_generation).to be(test_current_gen)
    expect(instance.previous_generation).to be(test_previous_gen)
  end

  it 'should create instance using constructor defauts' do
    instance = Enscalator::InstanceType::AwsInstance.new
    expect(instance.current_generation).to be_empty
    expect(instance.previous_generation).to be_empty
  end

end

describe 'Enscalator::InstanceType::EC2' do

  it 'should create EC2 instance type' do
    ec2 = Enscalator::InstanceType::EC2.new
    common_entries = [:general_purpose, :compute_optimized, :memory_optimized, :gpu]
    ec2_current_families = common_entries.dup.concat([:high_io_optimized, :dense_storage_optimized])
    ec2_previous_families = common_entries.dup.concat([:storage_optimized, :micro])
    expect(ec2.current_generation.keys).to include(*ec2_current_families)
    expect(ec2.previous_generation.keys).to include(*ec2_previous_families)
  end

end

describe 'Enscalator::InstanceType::RDS' do

  it 'should create RDS instance type' do
    rds = Enscalator::InstanceType::RDS.new
    common_entries = [:standard, :memory_optimized]
    rds_current_generation_families = common_entries.dup.concat([:burstable_performance])
    rds_previous_generation_families = common_entries.dup.concat([:micro])
    expect(rds.current_generation.keys).to include(*rds_current_generation_families)
    expect(rds.previous_generation.keys).to include(*rds_previous_generation_families)
  end

end