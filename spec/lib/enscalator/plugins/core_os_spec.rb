require 'spec_helper'
require 'semantic'

# Tests for public interfaces
describe 'Enscalator::Plugins::CoreOS' do

  it 'should create mapping template for CoreOS' do
    VCR.use_cassette 'coreos_init_mapping_in_template' do
      class CoreOSTestTemplate < Enscalator::EnAppTemplateDSL
        include Enscalator::Plugins::CoreOS
        define_method :tpl do
          core_os_init
        end
      end
      coreos_template = CoreOSTestTemplate.new
      mapping_under_test = coreos_template.instance_variable_get(:@dict)[:Mappings]['AWSCoreOSAMI']
      assert_mapping mapping_under_test
    end
  end

  it 'should return ami mapping for CoreOS latest version in alpha channel' do
    VCR.use_cassette 'coreos_latest_from_alpha_channel' do
      mapping = Enscalator::Plugins::CoreOS.get_channel_version(channel: :alpha)
      assert_mapping mapping
    end
  end

  it 'should return ami mapping for CoreOS 333.0.0 version in alpha channel' do
    VCR.use_cassette 'coreos_333_0_0_from_alpha_channel' do
      mapping = Enscalator::Plugins::CoreOS.get_channel_version(channel: :alpha)
      assert_mapping mapping
    end
  end

  it 'should return ami mapping for CoreOS latest version in beta channel' do
    VCR.use_cassette 'coreos_latest_from_beta_channel' do
      mapping = Enscalator::Plugins::CoreOS.get_channel_version(channel: :beta)
      assert_mapping mapping
    end
  end

  it 'should return ami mapping for CoreOS 444.4.0 version in beta channel' do
    VCR.use_cassette 'coreos_444_4_0_from_beta_channel' do
      mapping = Enscalator::Plugins::CoreOS.get_channel_version(channel: :beta)
      assert_mapping mapping
    end
  end

  it 'should return ami mapping for CoreOS latest version in stable channel' do
    VCR.use_cassette 'coreos_latest_from_stable_channel' do
      mapping = Enscalator::Plugins::CoreOS.get_channel_version(channel: :beta)
      assert_mapping mapping
    end
  end

  it 'should return ami mapping for CoreOS 522.4.0 version in stable channel' do
    VCR.use_cassette 'coreos_522_4_0_from_stable_channel' do
      mapping = Enscalator::Plugins::CoreOS.get_channel_version(channel: :beta)
      assert_mapping mapping
    end
  end

  it 'should return ami mapping for CoreOS specific version (626.0.0) regardless of channel' do
    VCR.use_cassette 'coreos_specific_version_626_0_0' do
      mapping = Enscalator::Plugins::CoreOS.get_specific_version(tag: '626.0.0')
      assert_mapping mapping # specific version only available in alpha channel
    end
  end

  it 'should return ami mapping for CoreOS specific version (612.1.0) regardless of channel' do
    VCR.use_cassette 'coreos_specific_version_612_1_0' do
      mapping = Enscalator::Plugins::CoreOS.get_specific_version(tag: '612.1.0')
      assert_mapping mapping # specific version only available in beta channel
    end
  end

  it 'should return ami mapping for CoreOS specific version (607.0.0) regardless of channel' do
    VCR.use_cassette 'coreos_specific_version_607_0_0' do
      mapping = Enscalator::Plugins::CoreOS.get_specific_version(tag: '607.0.0')
      assert_mapping mapping # specific version only available in stable channel
    end
  end

  it 'should raise exception when channel parameter is not valid' do
    expect { Enscalator::Plugins::CoreOS.get_channel_version(channel: :unstable) }.to raise_exception ArgumentError
  end

end

# Tests for private methods in Enscalator::Plugins::CoreOS eigenclass
describe 'Enscalator::Plugins::CoreOS.private_methods' do

  it 'should fetch mapping for specific version tag' do
    VCR.use_cassette 'coreos_522.5.0_from_stable_release_channel' do
      testUrl = 'http://stable.release.core-os.net/amd64-usr'
      mapping = Enscalator::Plugins::CoreOS.send(:fetch_mapping, testUrl, '522.5.0')
      expect(mapping.keys.size).to eq(9)
      expect(mapping).to include('eu-central-1' => {'pv' => 'ami-448dbd59', 'hvm' => 'ami-468dbd5b'})
      expect(mapping).to include('ap-northeast-1' => {'pv' => 'ami-0a05160b', 'hvm' => 'ami-0c05160d'})
      expect(mapping).to include('sa-east-1' => {'pv' => 'ami-27b00d3a', 'hvm' => 'ami-23b00d3e'})
      expect(mapping).to include('ap-southeast-2' => {'pv' => 'ami-b5295c8f', 'hvm' => 'ami-b7295c8d'})
      expect(mapping).to include('ap-southeast-1' => {'pv' => 'ami-ba0f27e8', 'hvm' => 'ami-b40f27e6'})
      expect(mapping).to include('us-east-1' => {'pv' => 'ami-3e750856', 'hvm' => 'ami-3c750854'})
      expect(mapping).to include('us-west-2' => {'pv' => 'ami-bf2d728f', 'hvm' => 'ami-bd2d728d'})
      expect(mapping).to include('us-west-1' => {'pv' => 'ami-8f534dca', 'hvm' => 'ami-8d534dc8'})
      expect(mapping).to include('eu-west-1' => {'pv' => 'ami-e76dec90', 'hvm' => 'ami-f96dec8e'})
      expect(mapping).not_to include('aaa' => {'bbb' => 'ami-123', 'ccc' => 'ami-456'})
    end
  end

  it 'should fetch mapping for the most recent version tag' do
    VCR.use_cassette 'coreos_latest_from_stable_release_channel' do
      testUrl = 'http://stable.release.core-os.net/amd64-usr'
      mapping = Enscalator::Plugins::CoreOS.send(:fetch_mapping, testUrl, nil)
      expect(mapping.keys.size).to eq(9)
      expect(mapping).to include('eu-central-1' => {'pv' => 'ami-0c300d11', 'hvm' => 'ami-0e300d13'})
      expect(mapping).to include('ap-northeast-1' => {'pv' => 'ami-b128dcb1', 'hvm' => 'ami-af28dcaf'})
      expect(mapping).to include('sa-east-1' => {'pv' => 'ami-2154ec3c', 'hvm' => 'ami-2354ec3e'})
      expect(mapping).to include('ap-southeast-2' => {'pv' => 'ami-bbb5c581', 'hvm' => 'ami-b9b5c583'})
      expect(mapping).to include('ap-southeast-1' => {'pv' => 'ami-fa0b3aa8', 'hvm' => 'ami-f80b3aaa'})
      expect(mapping).to include('us-east-1' => {'pv' => 'ami-343b195c', 'hvm' => 'ami-323b195a'})
      expect(mapping).to include('us-west-2' => {'pv' => 'ami-0989a439', 'hvm' => 'ami-0789a437'})
      expect(mapping).to include('us-west-1' => {'pv' => 'ami-83d533c7', 'hvm' => 'ami-8dd533c9'})
      expect(mapping).to include('eu-west-1' => {'pv' => 'ami-57950a20', 'hvm' => 'ami-55950a22'})
      expect(mapping).not_to include('aaa' => {'bbb' => 'ami-123', 'ccc' => 'ami-456'})
    end
  end

  it 'should raise exception when base_url parameter is not valid' do
    expect { Enscalator::Plugins::CoreOS.send(:fetch_mapping, '', nil) }.to raise_exception ArgumentError
    expect { Enscalator::Plugins::CoreOS.send(:fetch_mapping, nil, nil) }.to raise_exception ArgumentError
  end

  it 'should parse html from stable channel and return a list of Semantic::Version' do
    VCR.use_cassette 'coreos_versions_in_stable_release_channel' do
      testUrl = 'http://stable.release.core-os.net/amd64-usr'
      versions = Enscalator::Plugins::CoreOS.send(:fetch_versions, testUrl)
      expect(versions.size).to eq(14)
      expect(versions).to include(Semantic::Version.new('367.1.0'))
      expect(versions).to include(Semantic::Version.new('607.0.0'))
      expect(versions).not_to include(Semantic::Version.new('633.1.0'))
      expect(versions).not_to include(Semantic::Version.new('522.3.0'))
    end
  end

  it 'should parse html from beta channel and return a list of Semantic::Version' do
    VCR.use_cassette 'coreos_versions_in_beta_release_channel' do
      testUrl = 'http://beta.release.core-os.net/amd64-usr'
      versions = Enscalator::Plugins::CoreOS.send(:fetch_versions, testUrl)
      expect(versions.size).to eq(25)
      expect(versions).to include(Semantic::Version.new('522.3.0'))
      expect(versions).to include(Semantic::Version.new('607.0.0'))
      expect(versions).not_to include(Semantic::Version.new('591.0.0'))
    end
  end

  it 'should parse html from alpha channel and return a list of Semantic::Version' do
    VCR.use_cassette 'coreos_versions_in_alpha_release_channel' do
      testUrl = 'http://alpha.release.core-os.net/amd64-usr'
      versions = Enscalator::Plugins::CoreOS.send(:fetch_versions, testUrl)
      expect(versions.size).to eq(138)
      expect(versions).to include(Semantic::Version.new('261.0.0'))
      expect(versions).to include(Semantic::Version.new('505.1.0'))
      expect(versions).not_to include(Semantic::Version.new('522.3.0'))
    end
  end

  it 'should parse CoreOS ami mapping and return it in valid format' do
    testMapping = {
        :amis => [
            {
                :name => 'aws-region-1',
                :pv => 'ami-pv123abc',
                :hvm => 'ami-hvm123ab'
            },
            {
                :name => 'aws-region-2',
                :pv => 'ami-pv333abc',
                :hvm => 'ami-hvm222ab'
            }
        ]
    }.with_indifferent_access

    resMapping = Enscalator::Plugins::CoreOS.send(:parse_raw_mapping, testMapping)
    expect(resMapping.keys).to eq(testMapping['amis'].map { |a| a['name'] })
    expect(resMapping.values).to eq(testMapping['amis'].map { |a| a.reject { |k, _v| k == 'name' } })
  end
end
