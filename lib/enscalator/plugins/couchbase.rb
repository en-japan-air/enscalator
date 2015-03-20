module Enscalator
  module Couchbase
    def couchbase_init(db_name, bucket: nil, allocated_storage: 5, instance_class: 'm1.medium')
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

        fail "You need to provide a bucket for couchbase" if bucket.nil?
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
                         :UserData => base64(join(interpolate(_couchbase_user_data(bucket))))
                       })
    end

    def _couchbase_user_data(bucket)
      data =<<-EOF
        sleep 20
        sudo /opt/couchbase/bin/couchbase-cli cluster-init -c 127.0.0.1:8091 \
          -u Administrator \
          -p password \
          --cluster-init-password=3fA76JWtzYbm \
          --cluster-init-ramsize=3000
        sudo /opt/couchbase/bin/couchbase-cli node-init -c 127.0.0.1:8091 \
          -u Administrator \
          -p 3fA76JWtzYbm
        sudo /opt/couchbase/bin/couchbase-cli bucket-create -c 127.0.0.1:8091 \
           --bucket=#{bucket} \
           --bucket-type=couchbase \
           --bucket-password=3fA76JWtzYbm \
           --bucket-port=11211 \
           --bucket-ramsize=3000 \
           --bucket-replica=1 \
           --bucket-priority=low \
           --wait \
           -u Administrator -p 3fA76JWtzYbm
      EOF
    end
  end
end
