module Enscalator
  module RDS_Snapshot
    def rds_snapshot_init(snapshot_name,
                          allocated_storage: 5,
                          multizone: 'false',
                          parameter_group: '***REMOVED***',
                          instance_class: "db.m1.small")

      parameter_allocated_storage "RDS",
        default: allocated_storage,
        min: 5,
        max: 1024

      parameter 'SnapshotId',
                :Default => snapshot_name,
                :Description => 'Identifier for the DB snapshot to restore from',
                :Type => 'String',
                :MinLength => '1',
                :MaxLength => '64'

      parameter 'Multizone',
                :Default => multizone,
                :Description => 'Multizone deployment',
                :Type => 'String'

      parameter 'RDSParameterGroup',
                :Default => parameter_group,
                :Description => 'Custom parameter group for an RDS database family',
                :Type => 'String'

      parameter_username "RDS"

      parameter_password "RDS"

      parameter_instance_class "RDS", default: instance_class,
        allowed_values: %w(db.t1.micro db.m1.small db.m3.medium db.m3.large db.m3.xlarge
                     db.m3.2xlarge db.r3.large db.r3.xlarge db.r3.2xlarge db.r3.4xlarge
                     db.r3.8xlarge db.t2.micro db.t2.small db.t2.medium db.m2.xlarge db.m2.2xlarge
                     db.m2.4xlarge db.cr1.8xlarge db.m1.medium db.m1.large db.m1.xlarge)

      resource "RDSSubnetGroup", :Type => 'AWS::RDS::DBSubnetGroup', :Properties => {
        :DBSubnetGroupDescription => 'Subnet group within VPC',
        :SubnetIds => [
          ref_resource_subnet_a,
          ref_resource_subnet_c
        ],
        :Tags => [{:Key => "Name", :Value => "RDSSubnetGroup"}]
      }

      resource "RDSInstance", :Type => 'AWS::RDS::DBInstance', :Properties => {
        :Engine => 'MySQL',
        :PubliclyAccessible => 'false',
        :DBSnapshotIdentifier => ref("SnapshotId"),
        :MultiAZ => ref("Multizone"),
        :MasterUsername => ref("RDSUsername"),
        :MasterUserPassword => ref("RDSPassword"),
        :DBInstanceClass => ref("RDSInstanceClass"),
        :VPCSecurityGroups => [ ref_resource_security_group ],
        :DBSubnetGroupName => ref("RDSSubnetGroup"),
        :DBParameterGroupName => ref("RDSParameterGroup"),
        :AllocatedStorage => ref("RDSAllocatedStorage"),
        :Tags => [{:Key => "Name", :Value => "RDSInstance"}]
      }

      output "RDSEndpointAddress",
        :Description => "RDS Endpoint Address",
        :Value => get_att("RDSInstance", 'Endpoint.Address')

    end
  end
end
