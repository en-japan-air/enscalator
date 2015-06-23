require 'spec_helper'

include Enscalator

describe 'Enscalator::Plugins::RDS' do

  before(:each) do
    ::EnAppTemplateDSL.send(:remove_const,
                            :TestRDSInstance.to_s) if ::EnAppTemplateDSL.const_defined? :TestRDSInstance
    ::EnAppTemplateDSL.const_set(:TestRDSInstance, 'test_db')
  end

  it 'should create RDS template with default settings' do

    class RDSTestDefaultTemplate < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::RDS
      define_method :tpl do
        rds_init(TestRDSInstance)
      end
    end

    rds_template = RDSTestDefaultTemplate.new
    test_instance_name = ::EnAppTemplateDSL::TestRDSInstance
    dict = rds_template.instance_variable_get(:@dict)
    params_under_test = dict[:Parameters]
    resources_under_test = dict[:Resources]

    expected_parameters = %w{Name AllocatedStorage
                          StorageType Multizone ParameterGroup
                          InstanceType Username Password}.map { |p| "RDS#{test_instance_name}#{p}" }
    expect(params_under_test.keys).to include(*expected_parameters)

    subnet_res = "RDS#{test_instance_name}SubnetGroup"
    rds_instance_res = "RDS#{test_instance_name}Instance"
    expect(resources_under_test.keys).to include(*[subnet_res, rds_instance_res])
    expect(resources_under_test[rds_instance_res][:Properties].keys).not_to include(:DBSnapshotIdentifier)
    expect(dict[:Outputs].keys).to include("RDS#{test_instance_name}EndpointAddress")
  end

  it 'should create RDS template with tags passed from template dsl excluding name tag' do

    ::EnAppTemplateDSL.const_set(:TestTags,
                                 {
                                   Tags: [
                                     Key: 'TestTagKey',
                                     Value: 'TestTagValue'
                                   ]
                                 })

    class RDSTestTagsTemplate < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::RDS
      define_method :tpl do
        rds_init(TestRDSInstance,
                 properties: TestTags.deep_dup)
      end
    end

    rds_template = RDSTestTagsTemplate.new
    test_instance_name = ::EnAppTemplateDSL::TestRDSInstance
    test_instance_tags = ::EnAppTemplateDSL::TestTags
    dict = rds_template.instance_variable_get(:@dict)
    tags_under_test = dict[:Resources]["RDS#{test_instance_name}Instance"][:Properties][:Tags]
    expected_tags = test_instance_tags[:Tags].dup.concat([
                                                           {
                                                             Key: 'Name',
                                                             Value: "RDS#{test_instance_name}Instance"
                                                           }
                                                         ])
    expect(tags_under_test).to include(*expected_tags)

    ::EnAppTemplateDSL.send(:remove_const, :TestTags.to_s)
  end

  it 'should create RDS template with use_snapshot set to true' do

    class RDSTestSnapshotTemplate < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::RDS
      define_method :tpl do
        rds_init(TestRDSInstance,
                 use_snapshot: true)
      end
    end

    rds_template = RDSTestSnapshotTemplate.new
    test_instance_name = ::EnAppTemplateDSL::TestRDSInstance
    dict = rds_template.instance_variable_get(:@dict)
    resources_under_test = dict[:Resources]
    rds_resource_props = resources_under_test["RDS#{test_instance_name}Instance"][:Properties]
    expect(rds_resource_props).to include(:DBSnapshotIdentifier)
    expect(rds_resource_props).not_to include(:DBName)
  end

  after(:each) do
    ::EnAppTemplateDSL.send(:remove_const, :TestRDSInstance.to_s)
  end

end
