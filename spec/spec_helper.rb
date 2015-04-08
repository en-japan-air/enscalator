require 'enscalator'
require 'pry'
require 'webmock/rspec'

# disable all web requests
WebMock.disable_net_connect!(allow_localhost: true)

# configure custom responses to web requests
RSpec.configure do |config|
  config.before(:each) do

    # CoreOS versions in stable release channel
    stub_request(:get, /stable.release.core-os.net\/amd64-usr/)
        .with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(status: 200,
                  body: File.read(File.join(
                                      File.expand_path('stubs', File.dirname(__FILE__)),
                                      'coreos_stable_versions.html')),
                  headers: {})

    # CoreOS versions in alpha release channel
    stub_request(:get, /alpha.release.core-os.net\/amd64-usr/)
        .with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(status: 200,
                  body: File.read(File.join(
                                      File.expand_path('stubs', File.dirname(__FILE__)),
                                      'coreos_alpha_versions.html')),
                  headers: {})

    # CoreOS versions in beta release channel
    stub_request(:get, /beta.release.core-os.net\/amd64-usr/)
        .with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(status: 200,
                  body: File.read(File.join(
                                      File.expand_path('stubs', File.dirname(__FILE__)),
                                      'coreos_beta_versions.html')),
                  headers: {})

    # CoreOS AMI mapping for 522.5.0 version from stable channel
    stub_request(:get, /stable.release.core-os.net\/amd64-usr\/522.5.0\/coreos_production_ami_all.json/)
        .with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(status: 200,
                  body: File.read(File.join(
                                      File.expand_path('stubs', File.dirname(__FILE__)),
                                      'coreos_stable_522_5_0_amis.json')),
                  headers: {})

    # CoreOS AMI mapping for 607.0.0 version from stable channel
    stub_request(:get, /stable.release.core-os.net\/amd64-usr\/607.0.0\/coreos_production_ami_all.json/)
        .with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(status: 200,
                  body: File.read(File.join(
                                      File.expand_path('stubs', File.dirname(__FILE__)),
                                      'coreos_stable_607_0_0_amis.json')),
                  headers: {})

  end
end