module Enscalator
  module RDS
    def rds_init(db_name, allocated_storage: 5, instance_class: "db.m1.small")
      parameter_allocated_storage "RDS#{db_name}",
        default: allocated_storage,
        min: 5,
        max: 1024

      parameter_name "RDS#{db_name}"

      parameter_username "RDS#{db_name}"

      parameter_password "RDS#{db_name}"

      parameter_instance_class "RDS#{db_name}", default: instance_class,
        allowed_values: %w(db.m1.small db.m1.large db.m1.xlarge
                           db.m2.xlarge db.m2.2xlarge db.m2.4xlarge)

      resource "RDS#{db_name}SubnetGroup", :Type => 'AWS::RDS::DBSubnetGroup', :Properties => {
        :DBSubnetGroupDescription => 'Subnet group within VPC',
        :SubnetIds => [
          ref_resource_subnet_a,
          ref_resource_subnet_c
        ],
        :Tags => [{:Key => "Name", :Value => "RDS#{db_name}SubnetGroup"}]
      }

      resource "RDS#{db_name}Instance", :Type => 'AWS::RDS::DBInstance', :Properties => {
        :Engine => 'MySQL',
        :PubliclyAccessible => 'false',
        :DBName => ref("RDS#{db_name}Name"),
        :MultiAZ => 'false',
        :MasterUsername => ref("RDS#{db_name}Username"),
        :MasterUserPassword => ref("RDS#{db_name}Password"),
        :DBInstanceClass => ref("RDS#{db_name}InstanceClass"),
        :VPCSecurityGroups => [ ref_resource_security_group ],
        :DBSubnetGroupName => ref("RDS#{db_name}SubnetGroup"),
        :AllocatedStorage => ref("RDS#{db_name}AllocatedStorage"),
        :Tags => [{:Key => "Name", :Value => "RDS#{db_name}Instance"}]
      }
    end

  end
end
