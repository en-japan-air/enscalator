module Enscalator
  module Plugins
    # Redis on EC2 instance
    module Redis
      include Enscalator::Plugins::Ubuntu

      # Create new Redis instance
      #
      # @param [String] instance_name instance name
      # @param [String] key_name instance key
      # @param [String] instance_type instance type
      def redis_init(instance_name,
                     key_name:,
                     instance_type: 't2.medium')

        parameter "Ubuntu#{instance_name}KeyName",
                  Default: key_name,
                  Description: 'Keypair name',
                  Type: 'String'

        ubuntu_init instance_name, instance_type: instance_type, properties: { 'UserData' => redis_user_data }
      end

      def redis_user_data
        Base64.encode64(%q(
          #!/usr/bin/env bash
          apt-get update
          apt-get upgrade -y
          apt-get install -y redis-server
          sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
          service redis-server restart
        ).gsub(/^\s+/, ''))
      end
    end # Redis
  end # Plugins
end # Enscalator
