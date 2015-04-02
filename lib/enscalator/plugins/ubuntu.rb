require 'open-uri'

module Enscalator
  module Plugins
    module Ubuntu

      def ubuntu_init(instance_name,
                      storage_kind: 'ebs',
                      virtualization: 'paravirtual',
                      allocate_public_ip: false)
        @ubuntu_mapping ||=
          mapping 'AWSUbuntuAMI',
          begin
            body = open('https://cloud-images.ubuntu.com/query/trusty/server/released.current.txt') {|f| f.read}
            mapping = {}
            body.split("\n").map{|x| x.split("\t")}
            .select{|x| x[4] == storage_kind && x[10] == virtualization}
            .map{|x| (mapping[x[6]] ||= {})[x[5]] = x[7]}
            mapping.with_indifferent_access
          end

        parameter_keyname "Ubuntu#{instance_name}"

        parameter_allocated_storage "Ubuntu#{instance_name}",
          default: 5,
          min: 5,
          max: 1024

        parameter_instance_class "Ubuntu#{instance_name}", default: 'm1.medium',
          allowed_values: %w(m1.medium m1.large m1.xlarge m2.xlarge
                                m2.2xlarge m2.4xlarge c1.medium c1.xlarge
                                cc1.4xlarge cc2.8xlarge cg1.4xlarge)

        instance_vpc(
          "Ubuntu#{instance_name}",
          find_in_map('AWSUbuntuAMI', ref('AWS::Region'), 'amd64'),
          ref_resource_subnet_a,
          [ref_private_security_group, ref_resource_security_group],
          dependsOn:[], properties: {
            :KeyName => ref("Ubuntu#{instance_name}KeyName"),
            :InstanceType => ref("Ubuntu#{instance_name}InstanceClass")
          })

        resource "Ubuntu#{instance_name}PublicIpAddress",
                 :Type => 'AWS::EC2::EIP',
                 :Properties => { :InstanceId => ref("Ubuntu#{instance_name}") } if allocate_public_ip
      end

    end # Ubuntu
  end # Plugins
end # Enscalator
