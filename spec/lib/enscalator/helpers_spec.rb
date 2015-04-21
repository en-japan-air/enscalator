require 'spec_helper'

describe 'Enscalator::Asserts' do

  class TestFixture
    include Enscalator::Helpers
  end

  test_fixture = TestFixture.new

  it 'should create valid cloudformation client' do
    VCR.use_cassette 'aws_sdk_cf_client_init' do
      client = test_fixture.cfn_client('us-east-1')
      expect(client.class).to be Aws::CloudFormation::Client
    end
  end

  it 'should raise exception if region is not provided for cloudformation client' do
    expect { test_fixture.cfn_client('') }.to raise_exception ArgumentError
    expect { test_fixture.cfn_client(nil) }.to raise_exception ArgumentError
  end

  it 'should create valid cloudformation resource accessor' do
    client = test_fixture.cfn_client('us-east-1')
    resource = test_fixture.cfn_resource(client)
    expect(resource.class).to be Aws::CloudFormation::Resource
  end

  it 'should raise exception when resource accessor is used without valid client' do
    expect { test_fixture.cfn_resource('') }.to raise_exception ArgumentError
    expect { test_fixture.cfn_resource(nil) }.to raise_exception ArgumentError
  end

  it 'should create valid client for ec2' do
    VCR.use_cassette 'aws_sdk_ec2_client_init' do
      client = test_fixture.ec2_client('us-east-1')
      expect(client.class).to be Aws::EC2::Client
    end
  end

  it 'should raise exception when region is not provided for ec2 client' do
    expect { test_fixture.ec2_client('') }.to raise_exception ArgumentError
    expect { test_fixture.ec2_client(nil) }.to raise_exception ArgumentError
  end

  it 'should find amis using ec2 client and default parameters' do
    VCR.use_cassette 'aws_sdk_ec2_client_find_ami', :tag => :aws_credentials do
      client = test_fixture.ec2_client('us-east-1')
      images = test_fixture.find_ami(client).images
      assert_ami(images.sample.image_id)
    end
  end

  it 'should raise exception when trying to find ami providing not valid ec2 client' do
    expect { test_fixture.find_ami(nil) }.to raise_exception ArgumentError
    expect { test_fixture.find_ami('') }.to raise_exception ArgumentError
    expect { test_fixture.find_ami(test_fixture.cfn_client('us-east-1')) }.to raise_exception ArgumentError
  end

end
