require 'spec_helper'

describe Enscalator::Plugins::Debian do
  describe '#debian_init' do
    it 'creates mapping template for Debian using default parameter' do
      VCR.use_cassette 'debian_mapping_default_options' do
        # Test fixture for Debian template
        class DebianTestTemplate < Enscalator::EnAppTemplateDSL
          include Enscalator::Plugins::Debian
          define_method :tpl do
            debian_init
          end
        end
        debian_template = DebianTestTemplate.new
        dict = debian_template.instance_variable_get(:@dict)
        mapping_under_test = dict[:Mappings]['AWSDebianAMI']
        assert_mapping mapping_under_test, fields: AWS_VIRTUALIZATION.values
      end
    end

    it 'returns ami mapping for Debian 8 Jessie' do
      VCR.use_cassette 'debian_mapping_version_jessie' do
        mapping = described_class.get_mapping(release: :jessie)
        assert_mapping mapping, fields: AWS_VIRTUALIZATION.values
      end
    end

    it 'returns ami mapping for Debian 7 Wheezy' do
      VCR.use_cassette 'debian_mapping_version_wheezy' do
        mapping = described_class.get_mapping(release: :wheezy)
        assert_mapping mapping, fields: AWS_VIRTUALIZATION.values
      end
    end

    # Testing edge cases
    it 'fails when fetching mapping for Debian 8 Jessie for i386 arch' do
      VCR.use_cassette 'debian_mapping_version_jessie_i386' do
        mapping = described_class.get_mapping(release: :jessie, arch: :i386)
        expect(mapping).to be_empty
      end
    end

    it 'fails when fetching mapping for Debian 8 Jessie for i386 arch' do
      VCR.use_cassette 'debian_mapping_version_jessie_instance_store' do
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
