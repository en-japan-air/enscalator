# Coveralls
require 'simplecov'
require 'coveralls'
SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter 'spec/lib'
  add_filter 'spec/helpers'
end
Coveralls.wear!

require 'enscalator'

# Debugging
require 'pry'

# Recording and mocking web requests
require 'vcr'
require 'webmock/rspec'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

# Methods common for multiple tests
require 'helpers/test_helpers'
include TestHelpers