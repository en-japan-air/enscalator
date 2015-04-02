require 'Shellwords'

module Enscalator
  module Plugins
    module Couchbase

      def couchbase_init(db_name,
                         bucket: nil,
                         allocated_storage: 5,
                         instance_class: 'm1.medium')

        @couchbase_mapping ||=
          mapping 'AWSCouchbaseAMI', {
            :'us-east-1' => { :amd64 => 'ami-403b4328' },
            :'us-west-2' => { :amd64 => 'ami-c398c6f3' },
            :'us-west-1' => { :amd64 => 'ami-1a554c5f' },
            :'eu-west-1' => { :amd64 => 'ami-8129aaf6' },
            :'ap-southeast-1' => { :amd64 => 'ami-88745fda' },
            :'ap-northeast-1' => { :amd64 => 'ami-6a7b676b' },
            :'sa-east-1' => { :amd64 => 'ami-59229f44' }
        }

          fail 'You need to provide a bucket for couchbase' if bucket.nil?
          parameter_keyname "Couchbase#{db_name}"

          parameter_allocated_storage "Couchbase#{db_name}",
            default: allocated_storage,
            min: 5,
            max: 1024

          parameter_instance_class "Couchbase#{db_name}", default: instance_class,
            allowed_values: %w(m1.medium m1.large m1.xlarge m2.xlarge
                                m2.2xlarge m2.4xlarge c1.medium c1.xlarge
                                cc1.4xlarge cc2.8xlarge cg1.4xlarge)

            instance_vpc("Couchbase#{db_name}",
                         find_in_map('AWSCouchbaseAMI', ref('AWS::Region'), 'amd64'),
                         ref_resource_subnet_a,
                         [ref_private_security_group, ref_resource_security_group],
                         dependsOn:[], properties: {
                           :KeyName => ref("Couchbase#{db_name}KeyName"),
                           :InstanceType => ref("Couchbase#{db_name}InstanceClass"),
                           :UserData => Base64.encode64(_couchbase_user_data(bucket))
                         })
      end

      def _couchbase_user_data(bucket)
        data =<<-EOG
          #!/usr/bin/env bash
          while [[ ! -e /opt/couchbase/var/lib/couchbase/couchbase-server.pid ]];do
            sleep 20
            echo "wait for couchbase" >> /tmp/userdatalog
            service couchbase-server status >> /tmp/userdatalog
          done

          # Wait for everything to be initialized
          sleep 1m
          RAMSIZE=`cat /proc/meminfo | grep MemTotal | awk {'print $2'}`
          RAMSIZE=`echo "($RAMSIZE/1000*(75/100.0))" | bc -l | xargs printf %0.f`
          INSTANCE=`curl http://169.254.169.254/latest/meta-data/instance-id`
          /opt/couchbase/bin/couchbase-cli cluster-init -c 127.0.0.1:8091 \
            -u Administrator \
            -p $INSTANCE \
            --cluster-init-password=3fA76JWtzYbm \
            --cluster-init-ramsize=$RAMSIZE 2>&1 >> /tmp/userdatalog
          /opt/couchbase/bin/couchbase-cli node-init -c 127.0.0.1:8091 \
            -u Administrator \
            -p 3fA76JWtzYbm 2>&1 >> /tmp/userdatalog
          /opt/couchbase/bin/couchbase-cli bucket-create -c 127.0.0.1:8091 \
             --bucket=#{bucket} \
             --bucket-type=couchbase \
             --bucket-password=3fA76JWtzYbm \
             --bucket-port=11211 \
             --bucket-ramsize=$RAMSIZE \
             --bucket-replica=1 \
             --bucket-priority=low \
             --wait \
             -u Administrator -p 3fA76JWtzYbm 2>&1 >> /tmp/userdatalog
        EOG
      end

    end # module Couchbase
  end # module Plugins
end # module Enscalator
