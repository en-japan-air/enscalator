#!/usr/bin/env ruby

begin
  Object.const_get('OpenVPN')
rescue NameError
  require 'bundler/setup'
end
require 'openvpn'

# Run
OpenVPN::Runner.run!(ARGV)
