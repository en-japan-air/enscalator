require 'spec_helper'

describe 'Enscalator::RichTemplateDSL' do

  class RichTemplateFixture < Enscalator::RichTemplateDSL
    define_method :tpl do
      value Description: 'test template'
    end
  end

  def gen_instance_type_template(name, type: 't2.micro', allowed_values: [])
    test_fixture = RichTemplateFixture.new
    test_fixture.parameter_instance_type(name, type: type, allowed_values: allowed_values)
    generated_template = test_fixture.instance_variable_get(:@dict)
    generated_template[:Parameters]["#{name}InstanceType"]
  end

  it 'should use current generation instance type' do
    test_instance_name = 'test'
    test_instance_type = 't2.small'
    template_under_test = gen_instance_type_template(test_instance_name,
                                                     type: test_instance_type)
    expect(template_under_test[:Default]).to be(test_instance_type)
  end

  it 'should use previous generation (obsolete) instance type' do
    test_instance_name = 'test_obsolete'
    test_instance_type = 'm1.small'
    template_under_test = gen_instance_type_template(test_instance_name,
                                                     type: test_instance_type)
    expect(template_under_test[:Default]).to be(test_instance_type)
  end

  it 'should fail if instance type is not within range of supported types' do
    test_instance_name = 'test_failing'
    test_instance_type = 'z5.superbig'
    expect {
      gen_instance_type_template(test_instance_name, type: test_instance_type)
    }.to raise_exception RuntimeError
  end

  it 'should use allowed values when given instance type is also present there' do
    test_instance_name = 'test_allowed'
    test_instance_type = 'z5.superbig'
    test_allowed_values = %w(z5.superbig z5.supersmall)
    template_under_test = gen_instance_type_template(test_instance_name,
                                                     type: test_instance_type,
                                                     allowed_values: test_allowed_values)
    expect(template_under_test[:Default]).to be(test_instance_type)
    expect(template_under_test[:AllowedValues]).to be(test_allowed_values)
  end

  it 'should fail if instance type is not within range of allowed values' do
    test_instance_name = 'test_allowed'
    test_instance_type = 'z5.superbig'
    test_allowed_values = %w(z5.extrasmall z5.supersmall z4.extrahard)
    expect {
      gen_instance_type_template(test_instance_name,
                                 type: test_instance_type,
                                 allowed_values: test_allowed_values)
    }.to raise_exception RuntimeError
  end

end
