require 'spec_helper'

describe 'Enscalator::Plugins::RethinkDB' do

  it 'should return valid ami mapping' do
    mapping = Enscalator::Plugins::RethinkDB.mapping
    assert_mapping(mapping, fields: AWS_VIRTUALIZATION.values)
  end

end