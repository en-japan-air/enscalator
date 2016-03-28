require 'spec_helper'

describe Enscalator::Core::NetworkConfig do
  it 'returns valid vpc networking configuration' do
    network_conf = described_class.mapping_vpc_net
    expect(network_conf.keys).to include(*AWS_REGIONS)
    network_conf.values.map { |v| v[:VPC] }.each do |addr|
      ip_addr_block = IPAddress.parse(addr)
      expect(ip_addr_block.network?).to be_truthy
      expect(ip_addr_block.address).to eq(addr.split('/').first)
      expect(ip_addr_block.prefix).to eq(addr.split('/').last)
    end
  end
end
