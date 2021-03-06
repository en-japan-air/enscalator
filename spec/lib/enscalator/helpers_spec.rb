require 'spec_helper'

describe Enscalator::Helpers do
  # Fixture for testing all helpers
  class TestFixture
    include Enscalator::Helpers
  end

  let(:test_fixture) { TestFixture.new }
  let(:aws_test_region) { 'us-east-1' }
  let(:aws_test_profile) { 'some_profile' }
  let(:credentials_test_path) { 'spec/assets/aws/credentials' }

  before do |example|
    if example.metadata[:aws_shared_credentials]
      allow_any_instance_of(Aws::SharedCredentials).to receive(:default_path).and_return(credentials_test_path)
      if example.metadata[:aws_config]
        Aws.config.update(region: aws_test_region,
                          credentials: Aws::SharedCredentials.new(profile_name: aws_test_profile))
      end
    end
  end

  after do |example|
    if example.metadata[:aws_shared_credentials]
      allow_any_instance_of(Aws::SharedCredentials).to receive(:default_path).and_call_original
      Aws.config = {} if example.metadata[:aws_config]
    end
  end

  context 'when default options' do
    it 'creates valid cloudformation client' do
      client = test_fixture.cfn_client('us-east-1')
      expect(client.class).to be Aws::CloudFormation::Client
    end

    it 'raises exception if region is not provided for cloudformation client' do
      expect { test_fixture.cfn_client('') }.to raise_exception ArgumentError
      expect { test_fixture.cfn_client(nil) }.to raise_exception ArgumentError
    end

    it 'creates valid cloudformation resource accessor' do
      client = test_fixture.cfn_client('us-east-1')
      resource = test_fixture.cfn_resource(client)
      expect(resource.class).to be Aws::CloudFormation::Resource
    end

    it 'raises exception when resource accessor is used without valid client' do
      expect { test_fixture.cfn_resource('') }.to raise_exception ArgumentError
      expect { test_fixture.cfn_resource(nil) }.to raise_exception ArgumentError
    end

    it 'creates valid client for ec2' do
      client = test_fixture.ec2_client('us-east-1')
      expect(client.class).to be Aws::EC2::Client
    end

    it 'raises exception when region is not provided for ec2 client' do
      expect { test_fixture.ec2_client('') }.to raise_exception ArgumentError
      expect { test_fixture.ec2_client(nil) }.to raise_exception ArgumentError
    end

    it 'creates valid client for route53' do
      client = test_fixture.route53_client('us-east-1')
      expect(client.class).to be Aws::Route53::Client
    end

    it 'raises exception when region is not provided for route53 client' do
      expect { test_fixture.route53_client('') }.to raise_exception ArgumentError
      expect { test_fixture.route53_client(nil) }.to raise_exception ArgumentError
    end

    it 'finds amis using ec2 client and default parameters' do
      VCR.use_cassette 'aws_sdk_ec2_client_find_ami', tag: :aws_credentials do
        client = test_fixture.ec2_client('us-east-1')
        images = test_fixture.find_ami(client).images
        assert_ami(images.sample.image_id)
      end
    end

    it 'raises exception when trying to find ami with not valid ec2 client' do
      expect { test_fixture.find_ami(nil) }.to raise_exception ArgumentError
      expect { test_fixture.find_ami('') }.to raise_exception ArgumentError
      expect { test_fixture.find_ami(test_fixture.cfn_client('us-east-1')) }.to raise_exception ArgumentError
    end

    it 'generates ssh key name from app_name, region and stack_name' do
      test_app_name = 'TestBox'
      test_region = 'africa-1'
      test_stack_name = 'BatchProcessing'
      generated_key_name = test_fixture.gen_ssh_key_name(test_app_name, test_region, test_stack_name)
      expect(generated_key_name).to include(test_app_name.underscore)
      expect(generated_key_name).to include(test_region.underscore)
      expect(generated_key_name).to include(test_stack_name.underscore)
      expect(generated_key_name).to match Regexp.new(/[a-z0-9_]+/)
    end
  end

  context 'when custom region and profile parameters' do
    it 'creates valid cloudformation client ignoring passed arguments', :aws_shared_credentials, :aws_config do
      client = test_fixture.cfn_client(aws_test_region)
      expect(client.class).to be Aws::CloudFormation::Client
    end

    it 'creates valid client for ec2', :aws_shared_credentials, :aws_config do
      client = test_fixture.ec2_client('us-east-1')
      expect(client.class).to be Aws::EC2::Client
    end

    it 'creates valid client for route53', :aws_shared_credentials, :aws_config do
      client = test_fixture.route53_client('us-east-1')
      expect(client.class).to be Aws::Route53::Client
    end
  end

  describe '#init_aws_config' do
    before do |example|
      Aws.config = {} if example.metadata[:aws_config_empty]
    end

    after do |example|
      Aws.config = {} if example.metadata[:aws_config_empty]
    end

    context 'when only region is given' do
      it 'updates Aws global configuration with region only', :aws_shared_credentials, :aws_config_empty do
        test_fixture.init_aws_config(aws_test_region)
        expect(Aws.config.keys).to contain_exactly(:region)
        expect(Aws.config).to include(region: aws_test_region)
      end

      it 'fails with ArgumentError if region is blank', :aws_shared_credentials, :aws_config_empty do
        expect { test_fixture.init_aws_config }.to raise_exception ArgumentError
      end
    end

    context 'when both region and profile name are given' do
      it 'updates Aws global configuration with both options', :aws_shared_credentials, :aws_config_empty do
        test_fixture.init_aws_config(aws_test_region, profile_name: aws_test_profile)
        expect(Aws.config.keys).to contain_exactly(:region, :credentials)
        expect(Aws.config).to include(region: aws_test_region)
        test_credentials = Aws.config[:credentials]
        expect(test_credentials.is_a?(Aws::SharedCredentials)).to be_truthy
        expect(test_credentials.respond_to?(:profile_name)).to be_truthy
        expect(test_credentials.profile_name).to eq(aws_test_profile)
        expect(test_credentials.path).to eq(credentials_test_path)
      end
    end
  end

  describe '#flatten_hash' do
    it 'converts Hash with nested values to flat structure' do
      hash = { a: 'a', b: { c: 'c' } }
      expected_hash = { a: 'a', 'b.c': 'c' }
      expect(test_fixture.flatten_hash(hash)).to eq(expected_hash)
    end
  end
end
