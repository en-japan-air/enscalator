require 'spec_helper'

describe Enscalator::Plugins::CoreOS do
  describe '#core_os_init' do
    let(:app_name) { 'test_server' }
    let(:description) { 'This is a test template for CoreOS' }

    context 'when invoked with default parameters' do
      let(:template_fixture) do
        coreos_test_app_name = app_name
        coreos_test_description = description
        coreos_test_template_name = app_name.humanize.delete(' ')
        gen_richtemplate(coreos_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = coreos_test_app_name
          value(Description: coreos_test_description)
          mock_availability_zones
          core_os_init
        end
      end

      it 'generates mapping template for CoreOS' do
        VCR.use_cassette 'coreos_init_mapping_in_template' do
          cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
          coreos_template = template_fixture.new(cmd_opts)
          mapping_under_test = coreos_template.instance_variable_get(:@dict)[:Mappings]['AWSCoreOSAMI']
          assert_mapping mapping_under_test
        end
      end
    end
  end

  describe '#get_channel_version' do
    context 'when alpha channel' do
      let(:channel) { :alpha }
      it 'return ami mapping for CoreOS latest version' do
        VCR.use_cassette 'coreos_latest_from_alpha_channel' do
          mapping = described_class.get_channel_version(channel: channel)
          assert_mapping mapping
        end
      end

      it 'return ami mapping for CoreOS 333.0.0 version' do
        VCR.use_cassette 'coreos_333_0_0_from_alpha_channel' do
          mapping = described_class.get_channel_version(channel: channel)
          assert_mapping mapping
        end
      end
    end

    context 'when beta channel' do
      let(:channel) { :beta }
      it 'return ami mapping for CoreOS latest version in beta channel' do
        VCR.use_cassette 'coreos_latest_from_beta_channel' do
          mapping = described_class.get_channel_version(channel: channel)
          assert_mapping mapping
        end
      end

      it 'return ami mapping for CoreOS 444.4.0 version in beta channel' do
        VCR.use_cassette 'coreos_444_4_0_from_beta_channel' do
          mapping = described_class.get_channel_version(channel: channel)
          assert_mapping mapping
        end
      end
    end

    context 'when stable channel' do
      let(:channel) { :stable }
      it 'return ami mapping for CoreOS latest version in stable channel' do
        VCR.use_cassette 'coreos_latest_from_stable_channel' do
          mapping = described_class.get_channel_version(channel: channel)
          assert_mapping mapping
        end
      end

      it 'return ami mapping for CoreOS 522.4.0 version in stable channel' do
        VCR.use_cassette 'coreos_522_4_0_from_stable_channel' do
          mapping = described_class.get_channel_version(channel: channel)
          assert_mapping mapping
        end
      end
    end

    context 'when channel parameter is not valid' do
      it 'raises ArgumentError exception' do
        expect { described_class.get_channel_version(channel: :unstable) }.to raise_exception ArgumentError
      end
    end
  end

  describe '#get_specific_version' do
    it 'return ami mapping for CoreOS specific version (626.0.0) regardless of channel' do
      VCR.use_cassette 'coreos_specific_version_626_0_0' do
        mapping = described_class.get_specific_version(tag: '626.0.0')
        assert_mapping mapping # specific version only available in alpha channel
      end
    end

    it 'return ami mapping for CoreOS specific version (612.1.0) regardless of channel' do
      VCR.use_cassette 'coreos_specific_version_612_1_0' do
        mapping = described_class.get_specific_version(tag: '612.1.0')
        assert_mapping mapping # specific version only available in beta channel
      end
    end

    it 'return ami mapping for CoreOS specific version (607.0.0) regardless of channel' do
      VCR.use_cassette 'coreos_specific_version_607_0_0' do
        mapping = described_class.get_specific_version(tag: '607.0.0')
        assert_mapping mapping # specific version only available in stable channel
      end
    end
  end

  # Tests for private methods in CoreOS meta class
  describe 'class << self' do
    it 'fetches mapping for specific version tag' do
      VCR.use_cassette 'coreos_522.5.0_from_stable_release_channel' do
        test_url = 'http://stable.release.core-os.net/amd64-usr'
        mapping = described_class.send(:fetch_mapping, test_url, '522.5.0')
        expect(mapping.keys.size).to eq(9)
        expect(mapping).to include('eu-central-1' => { 'pv' => 'ami-448dbd59', 'hvm' => 'ami-468dbd5b' })
        expect(mapping).to include('ap-northeast-1' => { 'pv' => 'ami-0a05160b', 'hvm' => 'ami-0c05160d' })
        expect(mapping).to include('sa-east-1' => { 'pv' => 'ami-27b00d3a', 'hvm' => 'ami-23b00d3e' })
        expect(mapping).to include('ap-southeast-2' => { 'pv' => 'ami-b5295c8f', 'hvm' => 'ami-b7295c8d' })
        expect(mapping).to include('ap-southeast-1' => { 'pv' => 'ami-ba0f27e8', 'hvm' => 'ami-b40f27e6' })
        expect(mapping).to include('us-east-1' => { 'pv' => 'ami-3e750856', 'hvm' => 'ami-3c750854' })
        expect(mapping).to include('us-west-2' => { 'pv' => 'ami-bf2d728f', 'hvm' => 'ami-bd2d728d' })
        expect(mapping).to include('us-west-1' => { 'pv' => 'ami-8f534dca', 'hvm' => 'ami-8d534dc8' })
        expect(mapping).to include('eu-west-1' => { 'pv' => 'ami-e76dec90', 'hvm' => 'ami-f96dec8e' })
        expect(mapping).not_to include('aaa' => { 'bbb' => 'ami-123', 'ccc' => 'ami-456' })
      end
    end

    it 'fetches mapping for the most recent version tag' do
      VCR.use_cassette 'coreos_latest_from_stable_release_channel' do
        test_url = 'http://stable.release.core-os.net/amd64-usr'
        mapping = described_class.send(:fetch_mapping, test_url, nil)
        expect(mapping.keys.size).to eq(9)
        expect(mapping).to include('eu-central-1' => { 'pv' => 'ami-0c300d11', 'hvm' => 'ami-0e300d13' })
        expect(mapping).to include('ap-northeast-1' => { 'pv' => 'ami-b128dcb1', 'hvm' => 'ami-af28dcaf' })
        expect(mapping).to include('sa-east-1' => { 'pv' => 'ami-2154ec3c', 'hvm' => 'ami-2354ec3e' })
        expect(mapping).to include('ap-southeast-2' => { 'pv' => 'ami-bbb5c581', 'hvm' => 'ami-b9b5c583' })
        expect(mapping).to include('ap-southeast-1' => { 'pv' => 'ami-fa0b3aa8', 'hvm' => 'ami-f80b3aaa' })
        expect(mapping).to include('us-east-1' => { 'pv' => 'ami-343b195c', 'hvm' => 'ami-323b195a' })
        expect(mapping).to include('us-west-2' => { 'pv' => 'ami-0989a439', 'hvm' => 'ami-0789a437' })
        expect(mapping).to include('us-west-1' => { 'pv' => 'ami-83d533c7', 'hvm' => 'ami-8dd533c9' })
        expect(mapping).to include('eu-west-1' => { 'pv' => 'ami-57950a20', 'hvm' => 'ami-55950a22' })
        expect(mapping).not_to include('aaa' => { 'bbb' => 'ami-123', 'ccc' => 'ami-456' })
      end
    end

    it 'raises exception when base_url could be accessed, but required data is not found there' do
      VCR.use_cassette 'coreos_mapping_wrong_url' do
        test_url = 'http://stable.release.core-os.net/sparc-usr/'
        expect { described_class.send(:fetch_mapping, test_url, nil) }.to raise_exception OpenURI::HTTPError
      end
    end

    it 'raises exception when base_url parameter is not valid' do
      expect { described_class.send(:fetch_mapping, '', nil) }.to raise_exception ArgumentError
      expect { described_class.send(:fetch_mapping, nil, nil) }.to raise_exception ArgumentError
    end

    it 'parses html from stable channel and returns a list of Semantic::Version' do
      VCR.use_cassette 'coreos_versions_in_stable_release_channel' do
        test_url = 'http://stable.release.core-os.net/amd64-usr/'
        versions = described_class.send(:fetch_versions, test_url)
        expect(versions.size).to eq(14)
        expect(versions).to include(Semantic::Version.new('367.1.0'))
        expect(versions).to include(Semantic::Version.new('607.0.0'))
        expect(versions).not_to include(Semantic::Version.new('633.1.0'))
        expect(versions).not_to include(Semantic::Version.new('522.3.0'))
      end
    end

    it 'parses html from beta channel and returns a list of Semantic::Version' do
      VCR.use_cassette 'coreos_versions_in_beta_release_channel' do
        test_url = 'http://beta.release.core-os.net/amd64-usr/'
        versions = described_class.send(:fetch_versions, test_url)
        expect(versions.size).to eq(25)
        expect(versions).to include(Semantic::Version.new('522.3.0'))
        expect(versions).to include(Semantic::Version.new('607.0.0'))
        expect(versions).not_to include(Semantic::Version.new('591.0.0'))
      end
    end

    it 'parses html from alpha channel and returns a list of Semantic::Version' do
      VCR.use_cassette 'coreos_versions_in_alpha_release_channel' do
        test_url = 'http://alpha.release.core-os.net/amd64-usr/'
        versions = described_class.send(:fetch_versions, test_url)
        expect(versions.size).to eq(138)
        expect(versions).to include(Semantic::Version.new('261.0.0'))
        expect(versions).to include(Semantic::Version.new('505.1.0'))
        expect(versions).not_to include(Semantic::Version.new('522.3.0'))
      end
    end

    it 'parses CoreOS ami mapping and returns it in valid format' do
      test_mapping = {
        amis: [
          {
            name: 'aws-region-1',
            pv: 'ami-pv123abc',
            hvm: 'ami-hvm123ab'
          },
          {
            name: 'aws-region-2',
            pv: 'ami-pv333abc',
            hvm: 'ami-hvm222ab'
          }
        ]
      }.with_indifferent_access
      res_mapping = described_class.send(:parse_raw_mapping, test_mapping)
      expect(res_mapping.keys).to eq(test_mapping['amis'].map { |a| a['name'] })
      expect(res_mapping.values).to eq(test_mapping['amis'].map { |a| a.reject { |k, _v| k == 'name' } })
    end
  end
end
