require 'spec_helper'

describe Enscalator::Plugins::Debian do
  describe '#debian_init' do
    let(:app_name) { 'test_server' }
    let(:description) { 'This is a test template for Debian' }

    context 'when invoked with default parameters' do
      let(:template_fixture) do
        debian_test_app_name = app_name
        debian_test_description = description
        debian_test_template_name = app_name.humanize.delete(' ')
        gen_richtemplate(debian_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          @app_name = debian_test_app_name
          value(Description: debian_test_description)
          mock_availability_zones
          debian_init
        end
      end

      it 'creates mapping template for Debian' do
        VCR.use_cassette 'debian_mapping_version_jessie', allow_playback_repeats: true do
          cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
          debian_template = template_fixture.new(cmd_opts)
          dict = debian_template.instance_variable_get(:@dict)
          mapping_under_test = dict[:Mappings]['AWSDebianAMI']
          assert_mapping mapping_under_test, fields: AWS_VIRTUALIZATION.values
        end
      end
    end
  end

  describe '#get_mapping' do
    it 'returns ami mapping for Debian 8 Jessie' do
      VCR.use_cassette 'debian_mapping_version_jessie', allow_playback_repeats: true do
        mapping = described_class.get_mapping(release: :jessie)
        assert_mapping mapping, fields: AWS_VIRTUALIZATION.values
      end
    end

    it 'returns ami mapping for Debian 7 Wheezy' do
      VCR.use_cassette 'debian_mapping_version_wheezy', allow_playback_repeats: true do
        mapping = described_class.get_mapping(release: :wheezy)
        assert_mapping mapping, fields: AWS_VIRTUALIZATION.values
      end
    end

    # Testing edge cases
    it 'fails when fetching mapping for Debian 8 Jessie for i386 arch' do
      VCR.use_cassette 'debian_mapping_version_jessie', allow_playback_repeats: true do
        mapping = described_class.get_mapping(release: :jessie, arch: :i386)
        expect(mapping).to be_empty
      end
    end

    it 'fails when fetching mapping for Debian 8 Jessie for i386 arch' do
      VCR.use_cassette 'debian_mapping_version_jessie', allow_playback_repeats: true do
        mapping = described_class.get_mapping(release: :jessie, storage: :'instance-store')
        expect(mapping).to be_empty
      end
    end

    it 'raises ArgumentError exceptions when expected parameters not valid' do
      expect { described_class.get_mapping(release: :windows) }.to raise_exception ArgumentError
      expect { described_class.get_mapping(release: nil) }.to raise_exception ArgumentError
      expect { described_class.get_mapping(release: '') }.to raise_exception ArgumentError
      expect { described_class.get_mapping(storage: :magnetic) }.to raise_exception ArgumentError
      expect { described_class.get_mapping(storage: nil) }.to raise_exception ArgumentError
      expect { described_class.get_mapping(storage: '') }.to raise_exception ArgumentError
      expect { described_class.get_mapping(arch: :sh4) }.to raise_exception ArgumentError
      expect { described_class.get_mapping(arch: nil) }.to raise_exception ArgumentError
      expect { described_class.get_mapping(arch: '') }.to raise_exception ArgumentError
    end
  end
end
