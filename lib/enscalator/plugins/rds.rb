module Enscalator

  module Plugins

    # Amazon RDS instance
    module RDS

      # Create new Amazon RDS instance
      #
      # @param [String] db_name database name
      # @param [Boolean] use_snapshot use snapshot or not
      # @param [Integer] allocated_storage size of instance primary storage
      # @param [String] storage_type instance storage type
      # @param [String] multizone deploy as multizone or use only single availability zone
      # @param [String] parameter_group RDS instance parameter group
      # @param [String] instance_type instance type
      # @param [Hash] properties additional properties
      def rds_init(db_name,
                   use_snapshot: false,
                   allocated_storage: 5,
                   storage_type: 'gp2',
                   multizone: 'false',
                   parameter_group: '***REMOVED***',
                   instance_type: 'db.m1.small',
                   properties: {})

        parameter_name "RDS#{db_name}"

        parameter_allocated_storage "RDS#{db_name}",
                                    default: allocated_storage,
                                    min: 5,
                                    max: 1024


        parameter "RDS#{db_name}StorageType",
                  :Default => storage_type,
                  :Description => 'Storage type to be associated with the DB instance',
                  :Type => 'String',
                  :AllowedValues => %w{ gp2 standard io1 }

        parameter "RDS#{db_name}Multizone",
                  :Default => multizone,
                  :Description => 'Multizone deployment',
                  :Type => 'String'

        parameter "RDS#{db_name}ParameterGroup",
                  :Default => parameter_group,
                  :Description => 'Custom parameter group for an RDS database family',
                  :Type => 'String'

        parameter_instance_type "RDS#{db_name}",
                                type: instance_type,
                                allowed_values: %w(db.t1.micro db.m1.small db.m3.medium db.m3.large
                                                db.m3.xlarge db.m3.2xlarge db.r3.large db.r3.xlarge
                                                db.r3.2xlarge db.r3.4xlarge db.r3.8xlarge db.t2.micro
                                                db.t2.small db.t2.medium db.m2.xlarge db.m2.2xlarge
                                                db.m2.4xlarge db.cr1.8xlarge db.m1.medium db.m1.large
                                                db.m1.xlarge)

        parameter_username "RDS#{db_name}"

        parameter_password "RDS#{db_name}"

        resource "RDS#{db_name}SubnetGroup",
                 :Type => 'AWS::RDS::DBSubnetGroup',
                 :Properties => {
                   :DBSubnetGroupDescription => 'Subnet group within VPC',
                   :SubnetIds => [
                     ref_resource_subnet_a,
                     ref_resource_subnet_c
                   ],
                   :Tags => [
                     {
                       :Key => 'Name',
                       :Value => "RDS#{db_name}SubnetGroup"
                     }
                   ]
                 }

        # DBName and DBSnapshotIdentifier are mutually exclusive, thus
        # when snapshot_id is given DBName won't be included to resource parameters
        props = properties.deep_dup
        if use_snapshot
          parameter "RDS#{db_name}SnapshotId",
                    :Description => 'Identifier for the DB snapshot to restore from',
                    :Type => 'String',
                    :MinLength => '1',
                    :MaxLength => '64'
          props[:DBSnapshotIdentifier] = ref("RDS#{db_name}SnapshotId")
        else
          props[:DBName] = ref("RDS#{db_name}Name")
        end

        rds_instance_tags = [
          {
            :Key => 'Name',
            :Value => "RDS#{db_name}Instance"
          }
        ]

        # Set instance tags
        if props.has_key?(:Tags) && !props[:Tags].empty?
          props[:Tags].concat(rds_instance_tags)
        else
          props[:Tags] = rds_instance_tags
        end

        rds_props = {
          :Engine => 'MySQL',
          :PubliclyAccessible => 'false',
          :MultiAZ => ref("RDS#{db_name}Multizone"),
          :MasterUsername => ref("RDS#{db_name}Username"),
          :MasterUserPassword => ref("RDS#{db_name}Password"),
          :DBInstanceClass => ref("RDS#{db_name}InstanceClass"),
          :VPCSecurityGroups => [ref_resource_security_group],
          :DBSubnetGroupName => ref("RDS#{db_name}SubnetGroup"),
          :DBParameterGroupName => ref("RDS#{db_name}ParameterGroup"),
          :AllocatedStorage => ref("RDS#{db_name}AllocatedStorage"),
          :StorageType => ref("RDS#{db_name}StorageType")
        }

        resource "RDS#{db_name}Instance",
                 :Type => 'AWS::RDS::DBInstance',
                 :Properties => props.merge(rds_props)

        output "RDS#{db_name}EndpointAddress",
               :Description => "#{db_name} Endpoint Address",
               :Value => get_att("RDS#{db_name}Instance", 'Endpoint.Address')

      end

    end # RDS
  end # Plugins
end # Enscalator
