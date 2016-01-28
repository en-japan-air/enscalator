require 'spec_helper'

describe Enscalator::RichTemplateDSL do
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
    it 'returns valid values for region, stack and vpc name using provided accessors' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      expect(test_fixture.region).to eq(opts[:region])
      expect(test_fixture.stack_name).to eq(opts[:stack_name])
      expect(test_fixture.vpc_stack_name).to eq(opts[:vpc_stack_name])
    end

    it 'parses parameters option into valid Hash format' do
      test_params = {
        SomeKey1: 'SomeValue1',
        SomeKey2: 'SomeValue2'
      }.with_indifferent_access
      opts = default_cmd_opts(
        richtemplate.name,
        richtemplate.name.underscore).merge(parameters: test_params.map { |k, v| "#{k}=#{v}" }.join(';'))
      test_fixture = richtemplate.new(opts)
      expect(test_fixture.parameters).to eq(test_params)
    end

    describe '#private_hosted_zone' do
      let(:cmd_opts) { default_cmd_opts(richtemplate.name, richtemplate.name.underscore) }
      context 'when valid non-empty string' do
        it 'returns hosted zone in fqdn format' do
          test_private_zone_fqdn = 'somezone.'
          opts = cmd_opts.merge(private_hosted_zone: test_private_zone_fqdn)
          test_fixture = richtemplate.new(opts)
          expect(test_fixture.private_hosted_zone).to eq(test_private_zone_fqdn)
        end
      end
      context 'when nil' do
        it 'fails if its accessor was called' do
          opts = cmd_opts.merge(private_hosted_zone: nil)
          test_fixture = richtemplate.new(opts)
          expect do
            test_fixture.private_hosted_zone
          end.to raise_exception RuntimeError
        end
      end
    end

    describe '#public_hosted_zone' do
      let(:cmd_opts) { default_cmd_opts(richtemplate.name, richtemplate.name.underscore) }
      context 'when valid non-empty string' do
        it 'returns public hosted zone in fqdn format' do
          test_public_zone_fqdn = 'somezone.public.'
          opts = cmd_opts.merge(public_hosted_zone: test_public_zone_fqdn)
          test_fixture = richtemplate.new(opts)
          expect(test_fixture.public_hosted_zone).to eq(test_public_zone_fqdn)
        end
      end
      context 'when nil' do
        it 'fails if its accessor was called' do
          opts = cmd_opts.merge(public_hosted_zone: nil)
          test_fixture = richtemplate.new(opts)
          expect do
            test_fixture.public_hosted_zone
          end.to raise_exception RuntimeError
        end
      end
    end

    describe '#handle_trailing_dot' do
      let(:test_fixture) do
        richtemplate.new(default_cmd_opts(richtemplate.name, richtemplate.name.underscore))
      end
      context 'when string without trailing dot' do
        it 'appends trailing dot' do
          test_zone = 'somezone'
          expect(test_fixture.handle_trailing_dot(test_zone)).to eq(test_zone << '.')
        end
        context 'when string with trailing dot' do
          it 'uses provided string as is' do
            test_zone = 'somezone' << '.'
            expect(test_fixture.handle_trailing_dot(test_zone)).to eq(test_zone)
          end
        end
      end
    end

    it 'return all availability zones by default' do
      VCR.use_cassette 'richtemplate_all_availability_zones' do
        opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
        test_fixture = richtemplate.new(opts)
        az_list = test_fixture.read_availability_zones
        expect(az_list).not_to be_nil
        expect(az_list.size > 1).to be(true)
      end
    end

    it 'returns availability zones using provided accessor method' do
      VCR.use_cassette 'richtemplate_all_availability_zones', allow_playback_repeats: true do
        opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
        test_fixture = richtemplate.new(opts)
        az = test_fixture.send(:availability_zones) # should call `read_availability_zones` method internally
        expect(test_fixture.availability_zones).to eq(az)
      end
    end

    it 'returns availability zones specified in command-line options' do
      VCR.use_cassette 'richtemplate_specific_availability_zone' do
        opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore).merge(availability_zone: 'a')
        test_fixture = richtemplate.new(opts)
        az_list = test_fixture.read_availability_zones
        expect(az_list).not_to be_nil
        expect(az_list.size).to eq(1)
        expect(az_list.keys.first).to eq(opts[:availability_zone].to_sym)
      end
    end

    it 'fails if specified availability zones are valid, but not supported in given region' do
      VCR.use_cassette 'richtemplate_specific_availability_zone', allow_playback_repeats: true do
        opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore).merge(availability_zone: 'd')
        test_fixture = richtemplate.new(opts)
        expect do
          test_fixture.read_availability_zones
        end.to raise_exception RuntimeError
      end
    end

    it 'converts Hash to cloudformation template tags format' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_tags = {
        tagkey1: 'TagValue1',
        tagkey2: 'TagValue2'
      }
      properties = test_fixture.tags_to_properties(test_tags)
      test_tags.each do |k, v|
        expect(properties.find { |p| p[:Key] == k }[:Key]).to eq(k)
        expect(properties.find { |p| p[:Value] == v }[:Value]).to eq(v)
      end
    end

    it 'add sdescription to template dict' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      expect(test_fixture.description(description)[:Description]).to eq(description)
      expect(test_fixture.instance_variable_get(:@dict)[:Description]).to eq(description)
    end

    it 'uses current generation ec2 instance type' do
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

    it 'uses previous generation (obsolete) ec2 instance type' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
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
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_ec2_failing'
      test_instance_type = 'z5.superbig'
      expect do
        test_fixture.parameter_ec2_instance_type(test_instance_name, type: test_instance_type)
      end.to raise_exception RuntimeError
    end

    it 'uses current generation rds instance type' do
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

    it 'uses previous generation (obsolete) rds instance type' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
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
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_rds_failing'
      test_instance_type = 'db.z5.supersmall'
      expect do
        test_fixture.parameter_rds_instance_type(test_instance_name, type: test_instance_type)
      end.to raise_exception RuntimeError
    end

    it 'uses allowed values when given instance type is also present there' do
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

    it 'fails if instance type is not within range of allowed values' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_instance_name = 'test_failing_allowed_values'
      test_instance_type = 'z5.superbig'
      test_allowed_values = %w(z5.extrasmall z5.supersmall z4.extrahard)
      expect do
        test_fixture.parameter_instance_type(test_instance_name,
                                             test_instance_type,
                                             allowed_values: test_allowed_values)
      end.to raise_exception RuntimeError
    end

    it 'dynamically create parameter accessor' do
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
      expect(test_fixture.send("ref_#{test_method_name}".to_sym)).to eq(Ref: test_method_name)
      expect(test_fixture.instance_variable_get(:@dict)[:Parameters]).to eq("#{test_method_name}" => test_params)
    end

    it 'adds given list of blocks to the run_queue' do
      opts = default_cmd_opts(richtemplate.name, richtemplate.name.underscore)
      test_fixture = richtemplate.new(opts)
      test_str = 'this is test'
      test_items = [] << proc { test_str.dup }
      expect(test_fixture.instance_variable_get(:@run_queue)).to be_nil
      test_fixture.enqueue(test_items)
      expect(test_fixture.instance_variable_get(:@run_queue)).to eq(test_items)
      expect(test_fixture.instance_variable_get(:@run_queue).map(&:call)).to include(test_str)
    end
  end
end
