# encoding: UTF-8

module Enscalator
  module Templates
    class EnslurpCoreOS < Enscalator::EnAppTemplateDSL

      include Enscalator::Helpers
      include Enscalator::Plugins::CoreOS

      def tpl

        @app_name = 'EnSlurpCoreOS'
        @key_name = 'enslurp_core_os'
        @instance_class = 'm3.medium'
        @iam_instance_profile = "arn:aws:iam::***REMOVED***:instance-profile/#{@app_name}"
        @user_data = read_user_data('enslurp_core_os')

        pre_run do
          pre_setup stack_name: 'test-vpc',
                    region: @options[:region]

          # create ssh key for application at aws
          create_ssh_key @key_name,
                         @options[:region],
                         force_create: false
        end

        description 'EnSlurp CoreOS based infrastructure'

        core_os_init

        parameter_instance_class @app_name,
                                 default: @instance_class,
                                 allowed_values: %w(m3.medium m3.large m3.xlarge)

        resource "#{@app_name}LaunchConfiguration",
                 Type: 'AWS::AutoScaling::LaunchConfiguration',
                 Properties: {
                   AssociatePublicIpAddress: true,
                   EbsOptimized: false,
                   IamInstanceProfile: @iam_instance_profile,
                   ImageId: find_in_map('AWSCoreOSAMI', ref('AWS::Region'), :hvm),
                   BlockDeviceMappings: [
                     {
                       DeviceName: '/dev/xvdb',
                       Ebs: {
                         VolumeSize: 100,
                         DeleteOnTermination: true
                       }
                     }
                   ],
                   InstanceType: ref("#{@app_name}InstanceClass"),
                   SecurityGroups: [ref_private_security_group, ref_resource_security_group],
                   KeyName: @key_name,
                   UserData: Base64.encode64(@user_data)
                 }

        resource "#{@app_name}AutoScalingGroup",
                 Type: 'AWS::AutoScaling::AutoScalingGroup',
                 Properties: {
                   AvailabilityZones: get_availability_zones,
                   LaunchConfigurationName: ref("#{@app_name}LaunchConfiguration"),
                   VPCZoneIdentifier: [ref_resource_subnet_a, ref_resource_subnet_c],
                   DesiredCapacity: 0,
                   MinSize: 0,
                   MaxSize: 50,
                   Tags: [
                     {
                       Key: 'Name',
                       Value: @app_name,
                       PropagateAtLaunch: true
                     }
                   ]
                 }

        # Add SQS queue
        resource "#{@app_name}Queue",
                 Type: 'AWS::SQS::Queue',
                 Properties: {
                   QueueName: "#{@app_name}"
                 }

      end # def tpl

    end # class EnslurpCoreOS
  end # module Templates
end # module Enscalator
