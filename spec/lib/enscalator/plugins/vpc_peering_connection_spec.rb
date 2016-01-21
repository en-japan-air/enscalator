require 'spec_helper'

describe Enscalator::Plugins::VPCPeeringConnection do
  describe '#parameter_vpc_id' do
    let(:test_param_name) { 'somename' }
    let(:test_param_description) { 'this is somename parameter' }
    let(:test_param_vpc_id) { 'vpc-12345678' }
    let(:template_fixture) do
      gen_richtemplate('sometemplate'.humanize, Enscalator::RichTemplateDSL, [described_class], &proc {})
    end
    let(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }

    context 'when vpc id is given' do
      it 'uses all fields to generate parameter' do
        test_template = template_fixture.new(cmd_opts)
        dict = test_template.instance_variable_get(:@dict)
        expect(dict).to be_empty

        test_template.parameter_vpc_id(test_param_name, test_param_description, test_param_vpc_id)
        expect(dict).to include(:Parameters)
        expect(dict[:Parameters]).to include(test_param_name)
        test_params = dict[:Parameters][test_param_name]
        expect(test_params[:Description]).to eq(test_param_description)
        expect(test_params[:Default]).to eq(test_param_vpc_id)
      end
    end

    context 'when vpc id is not given' do
      it 'uses only name and description to generate parameter' do
        test_template = template_fixture.new(cmd_opts)
        dict = test_template.instance_variable_get(:@dict)
        expect(dict).to be_empty

        test_template.parameter_vpc_id(test_param_name, test_param_description)
        expect(dict[:Parameters][test_param_name]).not_to include(:Default)
      end
    end
  end

  describe '#vpc_peering_init' do
    let(:conn_name) { 'test_conn' }

    context 'when default invoked with default parameters' do
      let(:template_fixture) do
        vpc_peering_test_conn_name = conn_name
        vpc_peering_test_template_name = conn_name.humanize.delete(' ')
        gen_richtemplate(vpc_peering_test_template_name,
                         Enscalator::RichTemplateDSL,
                         [described_class]) do
          mock_availability_zones
          vpc_peering_init(vpc_peering_test_conn_name)
        end
      end

      it 'creates template for VPC Peering Connection' do
        cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
        vpc_peering_template = template_fixture.new(cmd_opts)
        dict = vpc_peering_template.instance_variable_get(:@dict)

        resource_under_test = dict[:Resources]
        expect(resource_under_test).to include(conn_name)
        expect(resource_under_test[conn_name][:Type]).to eq('AWS::EC2::VPCPeeringConnection')
        resource_props = resource_under_test[conn_name][:Properties]
        expected_props = {
          VpcId: ref("#{conn_name}VpcId"),
          PeerVpcId: ref("#{conn_name}PeerVpcId")
        }
        expect { expected_props.fetch(:Tags) }.to raise_error(KeyError)
        expect(resource_props).to include(expected_props)
      end
    end

    context 'when custom tags' do
      let(:tags) do
        [
          {
            Key: 'TestKey',
            Value: 'TestValue'
          }
        ]
      end
      let(:template_fixture) do
        vpc_peering_test_conn_name = conn_name
        vpc_peering_test_template_name = conn_name.humanize.delete(' ')
        vpc_peering_test_tags = tags
        gen_richtemplate(vpc_peering_test_template_name,
                         Enscalator::RichTemplateDSL,
                         [described_class]) do
          mock_availability_zones
          vpc_peering_init(vpc_peering_test_conn_name, tags: vpc_peering_test_tags)
        end
      end

      it 'creates template with custom tags included' do
        cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
        vpc_peering_template = template_fixture.new(cmd_opts)
        dict = vpc_peering_template.instance_variable_get(:@dict)
        resource_under_test = dict[:Resources]
        expect(resource_under_test[conn_name][:Properties][:Tags]).to include(*tags)
      end
    end
  end
end
