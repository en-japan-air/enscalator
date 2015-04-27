module Enscalator
  module Plugins
    # Auto scaling group plugin
    module AutoScale

      # Create new auto scaling group
      #
      # @param [String] image_id image id that will be used to launch instance
      # @param [String] auto_scale_name auto scaling group name (default: stack name)
      # @param [String] launch_config_props dictionary that is used to overwrite default launch configuration settings
      # @param [String] auto_scale_props dictionary that is used to overwrite default auto scaling group settings
      # @return [String] auto scaling group resource name
      def auto_scale_init(image_id,
                          auto_scale_name: nil,
                          launch_config_props: {},
                          auto_scale_props: {})

        @auto_scale_resource_name = 'AutoScale'
        @auto_scale_name = "#{auto_scale_name || aws_stack_name}AutoScale"

        pre_run do
          create_ssh_key @auto_scale_name.underscore,
                         region,
                         force_create: false
        end

        resource 'LaunchConfig',
                 Type: 'AWS::AutoScaling::LaunchConfiguration',
                 Properties: {
                   ImageId: image_id,
                   InstanceType: 'm3.medium',
                   KeyName: @auto_scale_name.underscore,
                   AssociatePublicIpAddress: false,
                   SecurityGroups: [ref_private_security_group, ref_application_security_group]
                 }.merge(launch_config_props)

        resource @auto_scale_resource_name,
                 Type: 'AWS::AutoScaling::AutoScalingGroup',
                 Properties: {
                   AvailabilityZones: get_availability_zones,
                   VPCZoneIdentifier: [
                     ref_resource_subnet_a,
                     ref_resource_subnet_c
                   ],
                   LaunchConfigurationName: ref('LaunchConfig'),
                   MinSize: 0,
                   MaxSize: 1,
                   DesiredCapacity: 1,
                   Tags: [
                     {
                       Key: 'Name',
                       Value: @auto_scale_name,
                       PropagateAtLaunch: true
                     }
                   ]
                 }.merge(auto_scale_props)

        # return resource name
        @auto_scale_resource_name
      end

    end # module AutoScale
  end # module Plugins
end # module Enscalator
