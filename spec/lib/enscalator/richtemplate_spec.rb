require 'spec_helper'

describe 'Enscalator::RichTemplateDSL' do

  class RichTemplateFixture < Enscalator::RichTemplateDSL
    define_method :tpl do
      value Description: 'test template'
    end
  end

  # Helpers to generate template that can be used for testing
  def gen_instance_type_template(name, type, allowed_values: [])
    test_fixture = RichTemplateFixture.new
    test_fixture.parameter_instance_type(name, type, allowed_values: allowed_values)
    generated_template = test_fixture.instance_variable_get(:@dict)
    generated_template[:Parameters]["#{name}InstanceType"]
  end

  def gen_ec2_instance_type_tpl(instance_name, type)
    ec2_test_fixture = RichTemplateFixture.new
    ec2_test_fixture.parameter_ec2_instance_type(instance_name, type: type)
    generated_template = ec2_test_fixture.instance_variable_get(:@dict)
    generated_template[:Parameters]["#{instance_name}InstanceType"]
  end

  def gen_rds_instance_type_tpl(instance_name, type)
    rds_test_fixture = RichTemplateFixture.new
    rds_test_fixture.parameter_rds_instance_type(instance_name, type: type)
    generated_template = rds_test_fixture.instance_variable_get(:@dict)
    generated_template[:Parameters]["#{instance_name}InstanceType"]
  end

  it 'should use current generation ec2 instance type' do
    test_instance_name = 'test_ec2'
    test_instance_type = 't2.small'
    template_under_test = gen_ec2_instance_type_tpl(test_instance_name, test_instance_type)
    expect(template_under_test[:Default]).to be(test_instance_type)
  end

  it 'should use previous generation (obsolete) ec2 instance type' do
    test_instance_name = 'test_ec2_obsolete'
    test_instance_type = 'm1.small'
    template_under_test = gen_ec2_instance_type_tpl(test_instance_name, test_instance_type)
    expect(template_under_test[:Default]).to be(test_instance_type)
  end

  it 'should fail if ec2 instance type is not within range of supported types' do
    test_instance_name = 'test_ec2_failing'
    test_instance_type = 'z5.superbig'
    expect {
      gen_ec2_instance_type_tpl(test_instance_name, test_instance_type)
    }.to raise_exception RuntimeError
  end

  it 'should use current generation rds instance type' do
    test_instance_name = 'test_rds'
    test_instance_type = 'db.m3.medium'
    template_under_test = gen_rds_instance_type_tpl(test_instance_name, test_instance_type)
    expect(template_under_test[:Default]).to be(test_instance_type)
  end

  it 'should use previous generation (obsolete) rds instance type' do
    test_instance_name = 'test_rds_obsolete'
    test_instance_type = 'db.t1.micro'
    template_under_test = gen_rds_instance_type_tpl(test_instance_name, test_instance_type)
    expect(template_under_test[:Default]).to be(test_instance_type)
  end

  it 'should fail if rds instance type is not within range of supported types' do
    test_instance_name = 'test_rds_failing'
    test_instance_type = 'db.z5.supersmall'
    expect {
      gen_rds_instance_type_tpl(test_instance_name, test_instance_type)
    }.to raise_exception RuntimeError
  end

  it 'should use allowed values when given instance type is also present there' do
    test_instance_name = 'test_allowed'
    test_instance_type = 'z5.superbig'
    test_allowed_values = %w(z5.superbig z5.supersmall)
    template_under_test = gen_instance_type_template(test_instance_name,
                                                     test_instance_type,
                                                     allowed_values: test_allowed_values)
    expect(template_under_test[:Default]).to be(test_instance_type)
    expect(template_under_test[:AllowedValues]).to be(test_allowed_values)
  end

  it 'should fail if instance type is not within range of allowed values' do
    test_instance_name = 'test_failing_allowed_values'
    test_instance_type = 'z5.superbig'
    test_allowed_values = %w(z5.extrasmall z5.supersmall z4.extrahard)
    expect {
      gen_instance_type_template(test_instance_name,
                                 test_instance_type,
                                 allowed_values: test_allowed_values)
    }.to raise_exception RuntimeError
  end

end
