require 'spec_helper'

describe 'Enscalator::InstanceType' do

  it 'should provide EC2 instance type' do
    ec2_instance_type = Enscalator::InstanceType.ec2_instance_type
    expect(ec2_instance_type.class).to be(Enscalator::InstanceType::EC2)
    ec2_instance_type.current_generation.values.flatten.each { |cg| assert_ec2_instance_type(cg) }
    ec2_instance_type.previous_generation.values.flatten.each { |pg| assert_ec2_instance_type(pg) }
    binding.pry
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