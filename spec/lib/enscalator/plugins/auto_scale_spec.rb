require 'spec_helper'

describe 'Enscalator::Plugins::AutoScale.auto_scale_init' do

  let(:app_name) { 'auto_scale_test' }
  let(:description) { 'This is test template for auto scale group' }
  let(:image_id) { 'ami-0123456a' }

  context 'when invoked with default parameters' do

    let(:template_name) { app_name.humanize.delete(' ') }
    let(:template_fixture) do
      as_test_app_name = app_name
      as_test_description = description
      as_test_image_id = image_id
      as_test_template_name = template_name
      gen_richtemplate(as_test_template_name,
                       Enscalator::EnAppTemplateDSL,
                       [Enscalator::Plugins::AutoScale]) do
        @app_name = as_test_app_name
        value(Description: as_test_description)
        mock_availability_zones
        auto_scale_init(as_test_image_id)
      end
    end

    it 'should generate valid template with default values' do
      cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
      as_template = template_fixture.new(cmd_opts)
      dict = as_template.instance_variable_get(:@dict)
      expect(dict[:Resources].keys).to include(*%w(LaunchConfig AutoScale))
      test_autoscale = dict[:Resources]['AutoScale']
      expect(test_autoscale[:Type]).to eq('AWS::AutoScaling::AutoScalingGroup')
      expect(test_autoscale[:Properties][:LaunchConfigurationName]).to eq({ Ref: 'LaunchConfig' })
      default_tag = { Key: 'Name', Value: "#{template_name.downcase}AutoScale", PropagateAtLaunch: true }
      expect(test_autoscale[:Properties][:Tags]).to include(default_tag)
      test_launchconfig = dict[:Resources]['LaunchConfig']
      expect(test_launchconfig[:Type]).to eq('AWS::AutoScaling::LaunchConfiguration')
      expect(test_launchconfig[:Properties][:ImageId]).to eq(image_id)
    end
  end

end