require 'spec_helper'

describe 'Enscalator::Plugins::Debian' do

  it 'should create mapping template for Debian using default parameter' do
    VCR.use_cassette 'debian_mapping_default_options' do
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

end
