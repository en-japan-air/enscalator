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
                   backup_retention_period: 5,
                   storage_type: 'gp2',
                   multizone: 'false',
                   engine: 'MySQL',
                   engine_version: '5.6',
                   parameter_group: 'default.mysql5.6',
                   instance_type: 'db.t2.small',
                   properties: {})

        parameter_name "RDS#{db_name}"

        parameter_rds_instance_type "RDS#{db_name}", type: instance_type

        parameter_allocated_storage "RDS#{db_name}",
                                    default: allocated_storage,
                                    min: 5,
                                    max: 1024

        parameter "RDS#{db_name}Engine",
                  Default: engine,
                  Description: 'DB engine type of the DB instance',
                  Type: 'String'

        parameter "RDS#{db_name}EngineVersion",
                  Default: engine_version,
                  Description: 'DB engine version of the DB instance',
                  Type: 'String'

        parameter "RDS#{db_name}StorageType",
                  Default: storage_type,
                  Description: 'Storage type to be associated with the DB instance',
                  Type: 'String',
                  AllowedValues: %w( gp2 standard io1 )

        parameter "RDS#{db_name}Multizone",
                  Default: multizone,
                  Description: 'Multizone deployment',
                  Type: 'String'

        parameter "RDS#{db_name}ParameterGroup",
                  Default: parameter_group,
                  Description: 'Custom parameter group for an RDS database family',
                  Type: 'String'

        parameter_username "RDS#{db_name}"

        parameter_password "RDS#{db_name}"

        resource "RDS#{db_name}SubnetGroup",
                 Type: 'AWS::RDS::DBSubnetGroup',
                 Properties: {
                   DBSubnetGroupDescription: 'Subnet group within VPC',
                   SubnetIds: ref_resource_subnets,
                   Tags: [
                     {
                       Key: 'Name',
                       Value: "RDS#{db_name}SubnetGroup"
                     }
                   ]
                 }

        # DBName and DBSnapshotIdentifier are mutually exclusive, thus
        # when snapshot_id is given DBName won't be included to resource parameters
        props = properties.deep_dup
        if use_snapshot
          parameter "RDS#{db_name}SnapshotId",
                    Description: 'Identifier for the DB snapshot to restore from',
                    Type: 'String',
                    MinLength: '1',
                    MaxLength: '64'
          props[:DBSnapshotIdentifier] = ref("RDS#{db_name}SnapshotId")
        else
          props[:DBName] = ref("RDS#{db_name}Name")
        end

        rds_instance_tags = [
          {
            Key: 'Name',
            Value: "RDS#{db_name}Instance"
          }
        ]

        # Set instance tags
        if props.key?(:Tags) && !props[:Tags].empty?
          props[:Tags].concat(rds_instance_tags)
        else
          props[:Tags] = rds_instance_tags
        end

        rds_props = {
          PubliclyAccessible: 'false',
          MultiAZ: ref("RDS#{db_name}Multizone"),
          Engine: ref("RDS#{db_name}Engine"),
          EngineVersion: ref("RDS#{db_name}EngineVersion"),
          MasterUsername: ref("RDS#{db_name}Username"),
          MasterUserPassword: ref("RDS#{db_name}Password"),
          DBInstanceClass: ref("RDS#{db_name}InstanceType"),
          VPCSecurityGroups: [ref_resource_security_group, ref_private_security_group],
          DBSubnetGroupName: ref("RDS#{db_name}SubnetGroup"),
          DBParameterGroupName: ref("RDS#{db_name}ParameterGroup"),
          AllocatedStorage: ref("RDS#{db_name}AllocatedStorage"),
          BackupRetentionPeriod: backup_retention_period,
          StorageType: ref("RDS#{db_name}StorageType")
        }

        rds_instance_resource_name = "RDS#{db_name}Instance"
        resource rds_instance_resource_name,
                 Type: 'AWS::RDS::DBInstance',
                 Properties: rds_props.merge(props)

        output "RDS#{db_name}EndpointAddress",
               Description: "#{db_name} Endpoint Address",
               Value: get_att("RDS#{db_name}Instance", 'Endpoint.Address')

        rds_instance_resource_name
      end

      # Ensure that plugin using this template is a subclass of EnAppTemplateDSL
      def self.included(klass)
        if klass.superclass != Enscalator::EnAppTemplateDSL
          fail("Plugin #{name.to_s.demodulize} requires template to be subclass of #{EnAppTemplateDSL}")
        end
      end
    end # RDS
  end # Plugins
end # Enscalator
