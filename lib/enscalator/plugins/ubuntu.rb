require 'open-uri'

module Enscalator
  module Ubuntu
    def ubuntu_init(instance_name)
      @ubuntu_mapping ||=
        mapping 'AWSUbuntuAMI',
        begin
          body = open('https://cloud-images.ubuntu.com/query/trusty/server/released.current.txt') {|f| f.read}
          mapping = {}
          body.split("\n").map{|x| x.split("\t")}
          .select{|x| x[4] == 'ebs' && x[10] == 'paravirtual'}
          .map{|x| (mapping[x[6]] ||= {})[x[5]] = x[7]}
          mapping.with_indifferent_access
        end
=begin
      {
        :'us-east-1' => { :i386 => 'ami-56fbaf3e', :amd64 => 'ami-8cecb8e4' },
        :'ap-northeast-1' => { :i386 => 'ami-4b7d9c4b', :amd64 => 'ami-bb7c9dbb' },
        :'eu-west-1' => { :i386 => 'ami-cdaa3fba', :amd64 => 'ami-b556c3c2' },
        :'ap-southeast-1' => { :i386 => 'ami-0c24105e', :amd64 => 'ami-a62410f4' },
        :'ap-southeast-2' => { :i386 => 'ami-952e58af', :amd64 => 'ami-212c5a1b' },
        :'us-west-2' => { :i386 => 'ami-31012601', :amd64 => 'ami-fd0027cd' },
        :'us-west-1' => { :i386 => 'ami-3af8e27f', :amd64 => 'ami-c6f9e383' },

        :'eu-central-1' => { :i386 => 'ami-0a407217', :amd64 => 'ami-5040724d' },
        :'sa-east-1' => { :i386 => 'ami-e7b30dfa', :amd64 => 'ami-c7b10fda' },
      }
=end

      parameter_keyname "Ubuntu#{db_name}"

      parameter_allocated_storage "Ubuntu#{db_name}",
        default: 5,
        min: 5,
        max: 1024

      parameter_instance_class "Ubuntu#{db_name}", default: 'm1.medium',
        allowed_values: %w(m1.medium m1.large m1.xlarge m2.xlarge
                              m2.2xlarge m2.4xlarge c1.medium c1.xlarge
                              cc1.4xlarge cc2.8xlarge cg1.4xlarge)

      instance_vpc(
        "Ubuntu#{db_name}",
        find_in_map('AWSUbuntuAMI', ref('AWS::Region'), 'amd64'),
        ref_resource_subnet_a,
        [ref_private_security_group, ref_resource_security_group],
        dependsOn:[], properties: {
          :KeyName => ref("Ubuntu#{db_name}KeyName"),
          :InstanceType => ref("Ubuntu#{db_name}InstanceClass")
        })
    end
  end
end
