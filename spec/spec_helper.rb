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

# Configuration for CI servers
credentials = begin
  Aws::SharedCredentials.new(profile_name: 'default')
rescue
  require 'yaml'
  profile = YAML.load_file('spec/assets/aws/credentials.yml')[:default]
  Aws.config[:credentials] = Aws::Credentials.new(profile[:aws_access_key_id],
                                                  profile[:aws_secret_access_key])
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!

  # Filter out AWS access and secret tokens
  c.filter_sensitive_data('<AWS_ACCESS_KEY_ID>', :aws_credentials) do
    credentials.access_key_id
  end

  c.filter_sensitive_data('<AWS_SECRET_ACCESS_KEY>', :aws_credentials) do
    credentials.secret_access_key
  end
end

# Methods common for multiple tests
require_relative 'helpers/asserts'
include Helpers::Asserts