require 'spec_helper'

describe OpenVPN do
  it 'has a version number' do
    expect(OpenVPN::VERSION).not_to be nil
  end
end
