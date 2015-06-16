require 'spec_helper'

describe 'Enscalator::Asserts' do

  class TestFixture
    include Enscalator::Helpers
  end

  test_fixture = TestFixture.new

  it 'should create valid cloudformation client' do
    client = test_fixture.cfn_client('us-east-1')
    expect(client.class).to be Aws::CloudFormation::Client
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
    client = test_fixture.ec2_client('us-east-1')
    expect(client.class).to be Aws::EC2::Client
  end

  it 'should create valid client for RDS' do
    expect(test_fixture.rds_client('us-east-1')).to be_a Aws::RDS::Client
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

  it 'should get user id of current aws account' do
    VCR.use_cassette 'aws_user_id' do
      expect(test_fixture.current_aws_user_id).not_to be_empty
    end
  end

  it 'should get arn of given region and RDS instance identifier' do
    expect(test_fixture.rds_arn('us-east-1', 'rds-instance-identifier')).not_to be_empty
  end

  it 'should get snapshots filtered by given tags' do
    client = Aws::RDS::Client.new(region: 'ap-northeast-1')
    tags = [{key: 'aws:cloudformation:stack-name', value: 'cc-storage'}]
    VCR.use_cassette 'aws_rds_snapshots' do
      expect(test_fixture.find_rds_snapshots(client, tags)).not_to be_empty
    end
  end

end
