require 'spec_helper'

describe 'Enscalator::RichTemplateDSL' do

  class RichTemplateFixture < Enscalator::RichTemplateDSL
    define_method :tpl do
      value Description: 'test template'
    end
  end

  def assert_instance_type(name, type)
    test_fixture = RichTemplateFixture.new
    test_fixture.parameter_instance_type(name, type: type)
    template_under_test = test_fixture.instance_variable_get(:@dict)
    expect(template_under_test[:Parameters]["#{name}InstanceType"][:Default]).to be(type)
  end

  it 'should use current generation instance type' do
    test_instance_name = 'test'
    test_instance_type = 't2.small'
    assert_instance_type(test_instance_name, test_instance_type)
  end

  it 'should use previous generation (obsolete) instance type' do
    test_instance_name = 'test_obsolete'
    test_instance_type = 't2.small'
    assert_instance_type(test_instance_name, test_instance_type)
  end

end
