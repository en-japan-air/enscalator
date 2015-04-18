require 'spec_helper'

describe 'Enscalator::Plugins::Ubuntu' do
  it 'should create mapping template for Ubuntu using default parameters' do
    VCR.use_cassette 'ubuntu_mapping_default_options' do
      class UbuntuTestTemplate < Enscalator::EnAppTemplateDSL
        include Enscalator::Plugins::Ubuntu
        define_method :tpl do
          ubuntu_init
        end
      end
      ubuntu_template = CoreOSTestTemplate.new
      mapping_under_test = ubuntu_template.tpl
      assert_mapping mapping_under_test
    end
  end
end