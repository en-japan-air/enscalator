require 'spec_helper'

describe Enscalator::Core::CfParameters do
  let(:app_name) { 'cf_parameters_template' }
  let(:description) { 'Template with parameters' }
  let(:cf_params_template) do
    cf_params_app_name = app_name
    cf_params_description = description
    cf_params_template_name = app_name.humanize.delete(' ')
    gen_richtemplate(cf_params_template_name, Enscalator::EnAppTemplateDSL) do
      @app_name = cf_params_app_name
      value(Description: cf_params_description)
      mock_availability_zones
    end
  end

  describe '#parameter_instance_type' do
    it 'uses allowed values when given instance type is also present there' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_allowed'
      test_instance_type = 'z5.superbig'
      test_allowed_values = %w(z5.superbig z5.supersmall)
      test_fixture.parameter_instance_type(test_instance_name, test_instance_type, allowed_values: test_allowed_values)
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(instance_type[:Default]).to be(test_instance_type)
      expect(instance_type[:AllowedValues]).to be(test_allowed_values)
    end

    it 'fails if allowed values were not given' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_failing_allowed_values'
      test_instance_type = 'z5.superbig'
      expect do
        test_fixture.parameter_instance_type(test_instance_name, test_instance_type)
      end.to raise_exception RuntimeError
    end

    it 'fails if instance type is not within range of allowed values' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_failing_allowed_values'
      test_instance_type = 'z5.superbig'
      test_allowed_values = %w(z5.extrasmall z5.supersmall z4.extrahard)
      expect do
        test_fixture.parameter_instance_type(test_instance_name, test_instance_type, allowed_values: test_allowed_values)
      end.to raise_exception RuntimeError
    end
  end

  describe '#parameter_ec2_instance_type' do
    it 'uses current generation ec2 instance type' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_ec2'
      test_instance_type = 't2.small'
      test_fixture.parameter_ec2_instance_type(test_instance_name, type: test_instance_type)
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      ec2_instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(ec2_instance_type[:Default]).to be(test_instance_type)
    end

    it 'uses previous generation (obsolete) ec2 instance type' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_ec2_obsolete'
      test_instance_type = 'm1.small'
      expect do
        test_fixture.parameter_ec2_instance_type(test_instance_name, type: test_instance_type)
      end.to output("Using obsolete instance type: #{test_instance_type}\n").to_stderr
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      ec2_instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(ec2_instance_type[:Default]).to be(test_instance_type)
    end

    it 'fails if ec2 instance type is not within range of supported types' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_ec2_failing'
      test_instance_type = 'z5.superbig'
      expect do
        test_fixture.parameter_ec2_instance_type(test_instance_name, type: test_instance_type)
      end.to raise_exception RuntimeError
    end
  end

  describe '#parameter_rds_instance_type' do

    it 'uses current generation rds instance type' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_rds'
      test_instance_type = 'db.t2.medium'
      test_fixture.parameter_rds_instance_type(test_instance_name, type: test_instance_type)
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      rds_instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(rds_instance_type[:Default]).to be(test_instance_type)
    end

    it 'uses previous generation (obsolete) rds instance type' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_rds_obsolete'
      test_instance_type = 'db.t1.micro'
      expect do
        test_fixture.parameter_rds_instance_type(test_instance_name, type: test_instance_type)
      end.to output("Using obsolete instance type: #{test_instance_type}\n").to_stderr
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      rds_instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(rds_instance_type[:Default]).to be(test_instance_type)
    end

    it 'fails if rds instance type is not within range of supported types' do
      opts = default_cmd_opts(cf_params_template.name, cf_params_template.name.underscore)
      test_fixture = cf_params_template.new(opts)
      test_instance_name = 'test_rds_failing'
      test_instance_type = 'db.z5.supersmall'
      expect do
        test_fixture.parameter_rds_instance_type(test_instance_name, type: test_instance_type)
      end.to raise_exception RuntimeError
    end
  end
end
