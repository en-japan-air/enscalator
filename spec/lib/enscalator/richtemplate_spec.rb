require 'spec_helper'

describe 'Enscalator::RichTemplateDSL' do
  let(:app_name) { 'richtemplate_test' }
  let(:description) { 'This is a template for richtemplate itself' }
  let(:richtemplate) do
    rt_test_app_name = app_name
    rt_test_description = description
    rt_test_template_name = app_name.humanize.delete(' ')
    gen_richtemplate(rt_test_template_name,
                     Enscalator::EnAppTemplateDSL) do
      @app_name = rt_test_app_name
      value(Description: rt_test_description)
      mock_availability_zones
    end
  end

  context 'with default template parameters' do
    it 'should return valid values for region, stack and vpc name using provided accessors' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      expect(test_fixture.region).to eq(opts[:region])
      expect(test_fixture.stack_name).to eq(opts[:stack_name])
      expect(test_fixture.vpc_stack_name).to eq(opts[:vpc_stack_name])
    end

    it 'should parse parameters option into valid Hash format' do
      test_params = {
        :SomeKey1 => 'SomeValue1',
        :SomeKey2 => 'SomeValue2'
      }.with_indifferent_access
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
               .merge({ parameters: test_params.map { |k, v| "#{k.to_s}=#{v}" }.join(';') })
      test_fixture = richtemplate.new(opts)
      expect(test_fixture.parameters).to eq(test_params)
    end

    it 'should properly handle provided hosted zone option' do
      test_zone = 'somezone'
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
               .merge({ hosted_zone: test_zone })
      test_fixture = richtemplate.new(opts)
      expect(test_fixture.hosted_zone).to eq(test_zone << '.')
    end

    it 'should properly handle provided hosted zone option with trailing dot' do
      test_zone = 'somezone' << '.'
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
               .merge({ hosted_zone: test_zone })
      test_fixture = richtemplate.new(opts)
      expect(test_fixture.hosted_zone).to eq(test_zone)
    end

    it 'should fail if hosted zone is not given, but its accessor was called' do
      test_zone = nil
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
               .merge({ hosted_zone: test_zone })
      test_fixture = richtemplate.new(opts)
      expect {
        test_fixture.hosted_zone
      }.to raise_exception RuntimeError
    end

    it 'should return all availability zones by default' do
      VCR.use_cassette 'richtemplate_all_availability_zones' do
        opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
        test_fixture = richtemplate.new(opts)
        az_list = test_fixture.get_availability_zones
        expect(az_list).not_to be_nil
        expect(az_list.size > 1).to be(true)
      end
    end

    it 'should return availability zones using provided accessor method' do
      VCR.use_cassette 'richtemplate_all_availability_zones', allow_playback_repeats: true do
        opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
        test_fixture = richtemplate.new(opts)
        az = test_fixture.send(:availability_zones) # should call `get_availability_zones` method internally
        expect(test_fixture.availability_zones).to eq(az)
      end
    end

    it 'should return availability zones specified in command-line options' do
      VCR.use_cassette 'richtemplate_specific_availability_zone' do
        opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
                 .merge({ availability_zone: 'a' })
        test_fixture = richtemplate.new(opts)
        az_list = test_fixture.get_availability_zones
        expect(az_list).not_to be_nil
        expect(az_list.size).to eq(1)
        expect(az_list.keys.first).to eq(opts[:availability_zone].to_sym)
      end
    end

    it 'should fail if specified availability zones is valid, but not supported in given region' do
      VCR.use_cassette 'richtemplate_specific_availability_zone', allow_playback_repeats: true do
        opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
                 .merge({ availability_zone: 'd' })
        test_fixture = richtemplate.new(opts)
        expect {
          test_fixture.get_availability_zones
        }.to raise_exception RuntimeError
      end
    end

    it 'should convert Hash to cloudformation template tags format' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_tags = {
        tagkey1: 'TagValue1',
        tagkey2: 'TagValue2'
      }
      properties = test_fixture.tags_to_properties(test_tags)
      test_tags.each do |k, v|
        expect(properties.select { |p| p[:Key] == k }.first[:Key]).to eq(k)
        expect(properties.select { |p| p[:Value] == v }.first[:Value]).to eq(v)
      end
    end

    it 'should add description to template dict' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      expect(test_fixture.description(description)[:Description]).to eq(description)
      expect(test_fixture.instance_variable_get(:@dict)[:Description]).to eq(description)
    end

    it 'should use current generation ec2 instance type' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_ec2'
      test_instance_type = 't2.small'
      test_fixture.parameter_ec2_instance_type(test_instance_name, type: test_instance_type)
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      ec2_instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(ec2_instance_type[:Default]).to be(test_instance_type)
    end

    it 'should use previous generation (obsolete) ec2 instance type' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_ec2_obsolete'
      test_instance_type = 'm1.small'
      test_fixture.parameter_ec2_instance_type(test_instance_name, type: test_instance_type)
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      ec2_instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(ec2_instance_type[:Default]).to be(test_instance_type)
    end

    it 'should fail if ec2 instance type is not within range of supported types' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_ec2_failing'
      test_instance_type = 'z5.superbig'
      expect {
        test_fixture.parameter_ec2_instance_type(test_instance_name, type: test_instance_type)
      }.to raise_exception RuntimeError
    end

    it 'should use current generation rds instance type' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_rds'
      test_instance_type = 'db.m3.medium'
      test_fixture.parameter_rds_instance_type(test_instance_name, type: test_instance_type)
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      rds_instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(rds_instance_type[:Default]).to be(test_instance_type)
    end

    it 'should use previous generation (obsolete) rds instance type' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_rds_obsolete'
      test_instance_type = 'db.t1.micro'
      test_fixture.parameter_rds_instance_type(test_instance_name, type: test_instance_type)
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      rds_instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(rds_instance_type[:Default]).to be(test_instance_type)
    end

    it 'should fail if rds instance type is not within range of supported types' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_rds_failing'
      test_instance_type = 'db.z5.supersmall'
      expect {
        test_fixture.parameter_rds_instance_type(test_instance_name, type: test_instance_type)
      }.to raise_exception RuntimeError
    end

    it 'should use allowed values when given instance type is also present there' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_allowed'
      test_instance_type = 'z5.superbig'
      test_allowed_values = %w(z5.superbig z5.supersmall)
      test_fixture.parameter_instance_type(test_instance_name,
                                           test_instance_type,
                                           allowed_values: test_allowed_values)
      template_under_test = test_fixture.instance_variable_get(:@dict)
      expect(template_under_test[:Parameters]["#{test_instance_name}InstanceType"]).to_not be_nil
      instance_type = template_under_test[:Parameters]["#{test_instance_name}InstanceType"]
      expect(instance_type[:Default]).to be(test_instance_type)
      expect(instance_type[:AllowedValues]).to be(test_allowed_values)
    end

    it 'should fail if instance type is not within range of allowed values' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_failing_allowed_values'
      test_instance_type = 'z5.superbig'
      test_allowed_values = %w(z5.extrasmall z5.supersmall z4.extrahard)
      expect {
        test_fixture.parameter_instance_type(test_instance_name,
                                             test_instance_type,
                                             allowed_values: test_allowed_values)
      }.to raise_exception RuntimeError
    end

    it 'should dynamically create parameter accessor' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_method_name, test_params = {
        some: {
          SomeKey1: 'SomeValue1',
          SomeKey2: 'SomeValue2'
        }
      }.with_indifferent_access.first

      # method should not be defined
      expect { test_fixture.send("ref_#{test_method_name}".to_sym) }.to raise_exception NoMethodError

      test_fixture.parameter(test_method_name, test_params)

      # method should be defined
      expect { test_fixture.send("ref_#{test_method_name}".to_sym) }.not_to raise_exception
      expect(test_fixture.send("ref_#{test_method_name}".to_sym)).to eq({ Ref: test_method_name })
      expect(test_fixture.instance_variable_get(:@dict)[:Parameters]).to eq({ "#{test_method_name}" => test_params })
    end

    it 'should add given list of blocks to the run_queue' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_str = 'this is test'
      test_items = [] << Proc.new { test_str.dup }
      expect(test_fixture.instance_variable_get(:@run_queue)).to be_nil
      test_fixture.enqueue(test_items)
      expect(test_fixture.instance_variable_get(:@run_queue)).to eq(test_items)
      expect(test_fixture.instance_variable_get(:@run_queue).map(&:call)).to include(test_str)
    end
  end
end
