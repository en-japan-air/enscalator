require 'shellwords'
require 'open-uri'
require 'nokogiri'
require 'semantic'

require_relative 'plugins/core_os'
require_relative 'plugins/elb'
require_relative 'plugins/auto_scale'
require_relative 'plugins/couchbase'
require_relative 'plugins/core_os'
require_relative 'plugins/elasticsearch'
require_relative 'plugins/ubuntu'
require_relative 'plugins/debian'
require_relative 'plugins/rethinkdb'
require_relative 'plugins/rds'
require_relative 'plugins/elastic_beanstalk'
require_relative 'plugins/elasticache'
require_relative 'plugins/elasticsearch_opsworks'
require_relative 'plugins/amazon_linux'
require_relative 'plugins/vpc_peering_connection'
require_relative 'plugins/nat_gateway'

module Enscalator
  # Namespace for enscalator plugins
  module Plugins
  end
end
