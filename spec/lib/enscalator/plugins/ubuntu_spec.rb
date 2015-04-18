require 'spec_helper'

describe 'Enscalator::Plugins::Ubuntu' do

  it 'should create mapping template for Ubuntu using default parameters' do
    VCR.use_cassette 'ubuntu_mapping_default_options' do
      class UbuntuTestTemplate < Enscalator::EnAppTemplateDSL
        include Enscalator::Plugins::Ubuntu
        define_method :tpl do
          ubuntu_init('test_server')
        end
      end
      ubuntu_template = UbuntuTestTemplate.new
      mapping_under_test = ubuntu_template.instance_variable_get(:@dict)[:Mappings]['AWSUbuntuAMI']
      assert_mapping mapping_under_test, keys: false
    end
  end

  it 'should return ami mapping for Ubuntu latest version' do
    VCR.use_cassette 'ubuntu_mapping_vivid' do
      mapping = Enscalator::Plugins::Ubuntu.get_mapping(release: :vivid)
      assert_mapping mapping, keys: false
    end
  end

end