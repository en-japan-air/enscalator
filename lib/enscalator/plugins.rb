# -*- encoding : utf-8 -*-

require_relative 'plugins/core_os'
require_relative 'plugins/elb'
require_relative 'plugins/auto_scale'
require_relative 'plugins/couchbase'
require_relative 'plugins/core_os'
require_relative 'plugins/elasticsearch'
require_relative 'plugins/ubuntu'
require_relative 'plugins/rethinkdb'
require_relative 'plugins/rds'

module Enscalator

  # Namespace for enscalator plugins
  module Plugins
  end

end
