# Coveralls
require 'simplecov'
require 'coveralls'
SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter 'lib/enscalator/templates' # don't track coverage for templates
  add_filter 'spec/lib'
  add_filter 'spec/helpers'
end
Coveralls.wear!

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'enscalator'

# Debugging (use binding.pry to directly inspect in given scope)
require 'pry'

# Recording and mocking web requests
require 'vcr'
require 'webmock/rspec'

# Configuration for CI servers
aws_credentials =
  if ENV['CI'].eql?('true') || ENV['TRAVIS'].eql?('true')
    profile = YAML.load_file('spec/assets/aws/credentials.yml')[:default]
    creds = Aws::Credentials.new(profile[:aws_access_key_id],
                                 profile[:aws_secret_access_key],
                                 profile[:session_token])
    stub = Class.new {
      define_method :initialize do |config|
        instance_variable_set('@config', config)
      end
      define_method :resolve do
        creds
      end
    }
    Aws.send(:remove_const, :CredentialProviderChain.to_s) if Aws.const_defined? :CredentialProviderChain
    Aws.const_set(:CredentialProviderChain, stub)
    creds
  else
    Aws::SharedCredentials.new
  end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!

  # Filter out AWS access and secret tokens
  c.filter_sensitive_data('<AWS_ACCESS_KEY_ID>', :aws_credentials) do
    aws_credentials.credentials.access_key_id
  end

  c.filter_sensitive_data('<AWS_SECRET_ACCESS_KEY>', :aws_credentials) do
    aws_credentials.credentials.secret_access_key
  end
end

# Methods common for multiple tests
require_relative 'helpers/asserts'
require_relative 'helpers/mocks'
include Helpers::Asserts
include Helpers::Mocks
