require 'spec_helper'

describe Enscalator::Plugins::VPCPeeringConnection do
  describe '#vpc_peering_init' do
    let(:conn_name) { 'test_conn' }

    context 'when default invoked with default parameters' do
      let(:template_fixture) do
        vpc_peering_test_conn_name = conn_name
        vpc_peering_test_template_name = conn_name.humanize.delete(' ')
        gen_richtemplate(vpc_peering_test_template_name,
                         Enscalator::EnAppTemplateDSL,
                         [described_class]) do
          mock_availability_zones
          vpc_peering_init(vpc_peering_test_conn_name)
        end
      end

      it 'creates template for VPC Peering Connection' do
        cmd_opts = default_cmd_opts(template_fixture.name, template_fixture.name.underscore)
        vpc_peering_template = template_fixture.new(cmd_opts)
        dict = vpc_peering_template.instance_variable_get(:@dict)

        parameters_under_test = dict[:Parameters]
        expect(parameters_under_test.keys).to include(*%W(#{conn_name}VpcId #{conn_name}PeerVpcId))

        resource_under_test = dict[:Resources]
        expect(resource_under_test).to include(conn_name)
        expect(resource_under_test[conn_name][:Type]).to eq('AWS::EC2::VPCPeeringConnection')
        expect { resource_under_test[conn_name].fetch(:Tags) }.to raise_error(KeyError)
        resource_props = resource_under_test[conn_name][:Properties]
        expected_props = {
          VpcId: ref("#{conn_name}VpcId"),
          PeerVpcId: ref("#{conn_name}PeerVpcId")
        }
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
                         Enscalator::EnAppTemplateDSL,
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
        expect(resource_under_test[conn_name][:Tags]).to include(*tags)
      end
    end
  end
end
