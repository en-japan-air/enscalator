require 'spec_helper'

describe Enscalator do
  it 'has a valid version number' do
    version = Enscalator::VERSION
    expect(version).to_not be_nil
    expect(version.split('.').size).to eq(3)
  end
end
