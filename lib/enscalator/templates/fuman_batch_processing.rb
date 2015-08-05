module Enscalator

  module Templates

    # Publicly accessible Fuman Batch processing instance
    class FumanBatchProcessing < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::Debian
      include Enscalator::Helpers

      def tpl
        warn '[Warning] Deploying publicly accessible instance'

        key_name = app_name.downcase
        instance_type = 'c3.2xlarge'
        public_hosted_zone = %w{datascience en-japan io}.join('.') << '.'

        pre_run do
          load_vpc_params

          # create ssh public/private keypair, save private key for the local user
          create_ssh_key key_name, region, force_create: false
        end

        description 'Debian instance with public ip attached'

        parameter_ec2_instance_type app_name, type: instance_type

        debian_init

        resource "#{app_name}SecurityGroup",
                 Type: 'AWS::EC2::SecurityGroup',
                 Properties: {
                   GroupDescription: "Enable access to the #{app_name} instance",
                   VpcId: vpc.id,
                   SecurityGroupIngress: [
                     {
                       IpProtocol: 'tcp',
                       FromPort: '22',
                       ToPort: '22',
                       CidrIp: '0.0.0.0/0',
                     }
                   ],
                   SecurityGroupEgress: [
                     {
                       IpProtocol: '-1',
                       FromPort: '0',
                       ToPort: '65535',
                       CidrIp: '0.0.0.0/0'
                     }
                   ],
                   Tags: [
                     {
                       Key: 'Name',
                       Value: [app_name, 'SG'].join
                     }
                   ]
                 }

        instance_vpc app_name,
                     find_in_map('AWSDebianAMI', ref('AWS::Region'), :hvm),
                     public_subnets.first,
                     [
                       ref_private_security_group,
                       ref_application_security_group,
                       ref("#{app_name}SecurityGroup")
                     ],
                     dependsOn: [],
                     properties: {
                       KeyName: key_name,
                       InstanceType: ref("#{app_name}InstanceType"),
                       BlockDeviceMappings: [
                         {
                           DeviceName: '/dev/sdb',
                           VirtualName: 'ephemeral0'
                         },
                         {
                           DeviceName: '/dev/sdc',
                           VirtualName: 'ephemeral1'
                         }
                       ],
                       Tags: [
                         {
                           Key: 'Name',
                           Value: app_name
                         },
                         {
                           Key: 'Billing',
                           Value: 'InnovationLab'
                         }
                       ],
                       UserData: Base64.encode64(read_user_data('python_data_proc'))
                     }

        # Provide public ip for instance
        resource "#{app_name}PublicIpAddress",
                 Type: 'AWS::EC2::EIP',
                 Properties: {
                   InstanceId: ref(app_name)
                 }

        # Add A record for public ip address
        resource "#{app_name}Hostname",
                 Type: 'AWS::Route53::RecordSet',
                 Properties: {
                   Name: %W{fumanbatch #{public_hosted_zone}}.join('.'),
                   HostedZoneName: public_hosted_zone,
                   Comment: 'A record for fumanbatch',
                   TTL: 300,
                   Type: 'A',
                   ResourceRecords: [
                     ref("#{app_name}PublicIpAddress",)
                   ]
                 }
      end

    end # class FumanBatchProcessing
  end # module Templates
end # module Enscalator
