require 'spec_helper'

describe Enscalator::Plugins::RethinkDB do
  describe '#mapping' do
    it 'returns valid ami mapping' do
      mapping = described_class.mapping
      assert_mapping(mapping, fields: AWS_VIRTUALIZATION.values)
    end
  end
end
