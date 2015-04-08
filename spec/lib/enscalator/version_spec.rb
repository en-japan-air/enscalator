require 'spec_helper'

describe 'Enscalator::Version' do
  it 'should be current valid version number' do
    version = Enscalator::VERSION
    expect(version).to_not be_nil
    expect(version.split('.').size).to eq(3)
  end
end