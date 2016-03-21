require 'spec_helper'

describe Enscalator::Plugins::NATGateway do
  describe '#nat_gateway_init' do
    let(:test_nat_gateway) { 'TestNatGateway' }
    let(:test_public_subnet) { 'TestPublicSubnet' }
    let(:test_route_table) { 'TestRouteTable' }
    let(:test_depends_on_list) { ['TestGatewayToInternet'] }
    let(:test_template_params) do
      nat_gateway = test_nat_gateway
      public_subnet = test_public_subnet
      route_table = test_route_table
      depends_on = test_depends_on_list
      proc { nat_gateway_init(nat_gateway, public_subnet, route_table, depends_on: depends_on) }
    end
    subject(:template_fixture) do
      gen_richtemplate('natgatewaytest'.humanize, Enscalator::RichTemplateDSL, [described_class], &test_template_params)
    end
    subject(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }
    context 'when invoked with valid parameters' do
      it 'allocates elastic ip, nat gateway and route rule resources' do
        test_template = template_fixture.new(cmd_opts)
        dict = test_template.instance_variable_get(:@dict)
        resources_under_test = dict[:Resources]
        expect(resources_under_test).to have_key(test_nat_gateway)
        nat_gateway = resources_under_test[test_nat_gateway]
        expect(nat_gateway[:Type]).to eq('AWS::EC2::NatGateway')
        expect(nat_gateway[:DependsOn]).to include(*test_depends_on_list)
        expect(nat_gateway[:Properties].keys).to include(*[:AllocationId, :SubnetId])
        expect(resources_under_test).to have_key("#{test_nat_gateway}EIP")
        eip = resources_under_test["#{test_nat_gateway}EIP"]
        expect(eip[:Type]).to eq('AWS::EC2::EIP')
        expect(eip[:DependsOn]).to include(*test_depends_on_list)
        expect(eip[:Properties]).to include(Domain: 'vpc')
        expect(resources_under_test).to have_key("#{test_nat_gateway}Route")
        route_rule = resources_under_test["#{test_nat_gateway}Route"]
        expect(route_rule[:Type]).to eq('AWS::EC2::Route')
        expect(route_rule[:DependsOn]).to include(*test_depends_on_list)
        expect(route_rule[:Properties].keys).to include(*[:RouteTableId, :NatGatewayId, :DestinationCidrBlock])
        expect(route_rule[:Properties][:DestinationCidrBlock]).to eq('0.0.0.0/0')
      end
    end

    context 'when custom destination cidr block is given' do
      let(:test_dest_cidr_block) { '172.0.0.0/0' }
      let(:test_template_params) do
        nat_gateway = test_nat_gateway
        public_subnet = test_public_subnet
        route_table = test_route_table
        depends_on = test_depends_on_list
        dest_cidr_block = test_dest_cidr_block
        proc do
          nat_gateway_init(nat_gateway, public_subnet, route_table,
                           dest_cidr_block: dest_cidr_block, depends_on: depends_on)
        end
      end
      subject(:template_fixture) do
        gen_richtemplate('testnatcidr'.humanize, Enscalator::RichTemplateDSL, [described_class], &test_template_params)
      end
      subject(:cmd_opts) { default_cmd_opts(template_fixture.name, template_fixture.name.underscore) }

      it 'gets added to route rule' do
        test_template = template_fixture.new(cmd_opts)
        dict = test_template.instance_variable_get(:@dict)
        resources_under_test = dict[:Resources]
        expect(resources_under_test).to have_key("#{test_nat_gateway}Route")
        route_rule = resources_under_test["#{test_nat_gateway}Route"]
        expect(route_rule[:Properties][:DestinationCidrBlock]).to eq(test_dest_cidr_block)
      end
    end
  end
end
