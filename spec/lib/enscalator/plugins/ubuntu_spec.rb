require 'spec_helper'

describe 'Enscalator::Plugins::Ubuntu' do

  it 'should create mapping template for Ubuntu using default parameters' do
    VCR.use_cassette 'ubuntu_mapping_default_options' do
      class UbuntuTestTemplate < Enscalator::EnAppTemplateDSL
        include Enscalator::Plugins::Ubuntu
        define_method :tpl do
          mock_availability_zones
          ubuntu_init('test_server')
        end
      end

      ubuntu_template = UbuntuTestTemplate.new
      dict = ubuntu_template.instance_variable_get(:@dict)

      mapping_under_test = dict[:Mappings]['AWSUbuntuAMI']
      assert_mapping mapping_under_test, fields: AWS_VIRTUALIZATION.values

      resource_under_test = dict[:Resources]
      expect(resource_under_test.keys).to include('Ubuntutest_server')
    end
  end

  it 'should return ami mapping for Ubuntu latest version' do
    VCR.use_cassette 'ubuntu_mapping_version_vivid' do
      mapping = Enscalator::Plugins::Ubuntu.get_mapping(release: :vivid)
      assert_mapping mapping, fields: AWS_VIRTUALIZATION.values
    end
  end

  it 'should return ami mapping for Ubuntu version using release codename (trusy)' do
    VCR.use_cassette 'ubuntu_mapping_version_trusty' do
      mapping = Enscalator::Plugins::Ubuntu.get_mapping(release: :trusty)
      assert_mapping mapping, fields: AWS_VIRTUALIZATION.values
    end
  end

  it 'should return ami mapping for Ubuntu version using release version number (trusy)' do
    VCR.use_cassette 'ubuntu_mapping_version_14_04' do
      mapping = Enscalator::Plugins::Ubuntu.get_mapping(release: '14.04')
      assert_mapping mapping, fields: AWS_VIRTUALIZATION.values
    end
  end

  it 'should return ami mapping for image with root storage instance-store (utopic)' do
    VCR.use_cassette 'ubuntu_mapping_version_utopic_instance_store' do
      mapping = Enscalator::Plugins::Ubuntu.get_mapping(release: :utopic, storage: :'instance-store')
      assert_mapping mapping, fields: AWS_VIRTUALIZATION.values
    end
  end

  it 'should return ami mapping for i386 image with root storage instance-store (utopic)' do
    VCR.use_cassette 'ubuntu_mapping_version_utopic_instance_store_arch_i386' do
      mapping = Enscalator::Plugins::Ubuntu.get_mapping(release: :utopic, storage: :'instance-store', arch: :i386)
      assert_mapping mapping, fields: ['paravirtual']
    end
  end

  it 'should raise ArgumentError exceptions when expected parameters not valid' do
    expect { Enscalator::Plugins::Ubuntu.get_mapping(release: :windows) }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::Ubuntu.get_mapping(release: nil) }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::Ubuntu.get_mapping(release: '') }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::Ubuntu.get_mapping(storage: :magnetic) }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::Ubuntu.get_mapping(storage: nil) }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::Ubuntu.get_mapping(storage: '') }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::Ubuntu.get_mapping(arch: :sh4) }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::Ubuntu.get_mapping(arch: nil) }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::Ubuntu.get_mapping(arch: '') }.to raise_exception ArgumentError
  end

end