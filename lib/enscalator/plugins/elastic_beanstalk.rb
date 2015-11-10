module Enscalator
  module Plugins
    # Collection of methods to work with Elastic Beanstalk
    module ElasticBeanstalk
      include Enscalator::Helpers

      def elastic_beanstalk_app(app_name,
                                stack_name,
                                ssh_key: app_name,
                                solution_stack_name: '64bit Amazon Linux 2015.09 v2.0.4 running Ruby 2.2 (Passenger Standalone)',
                                instance_type: 't2.small'
                               )

        properties = {
          ApplicationName: app_name,
          Description: "#{app_name} in #{stack_name} stack",
          ConfigurationTemplates:
            [
              {
                TemplateName: 'DefaultConfiguration',
                Description: 'Default Configuration Version 1.0 - with SSH access',
                SolutionStackName: solution_stack_name,
                OptionSettings: [
                  {
                    'Namespace': 'aws:autoscaling:launchconfiguration',
                    'OptionName': 'EC2KeyName',
                    'Value': ssh_key
                  },
                  {
                    'Namespace': 'aws:ec2:vpc',
                    'OptionName': 'VPCId',
                    'Value': vpc.id
                  },
                  {
                    'Namespace': 'aws:ec2:vpc',
                    'OptionName': 'Subnets',
                    'Value': { 'Fn::Join': [',', ref_application_subnets] }
                  },
                  {
                    'Namespace': 'aws:ec2:vpc',
                    'OptionName': 'ELBSubnets',
                    'Value': { 'Fn::Join': [',', public_subnets] }
                  },
                  {
                    'Namespace': 'aws:autoscaling:launchconfiguration',
                    'OptionName': 'SecurityGroups',
                    'Value': { 'Fn::Join': [',', [ref_application_security_group, ref_private_security_group]] }
                  },
                  {
                    'Namespace': 'aws:autoscaling:launchconfiguration',
                    'OptionName': 'InstanceType',
                    'Value': instance_type
                  }
                ]
              }
            ]
        }

        elastic_beanstalk_resource_name = "#{app_name}BeanstalkApp"

        resource elastic_beanstalk_resource_name,
                 Type: 'AWS::ElasticBeanstalk::Application',
                 Properties: properties

        elastic_beanstalk_resource_name
      end
    end # module ElasticBeanstalk
  end # module Plugins
end # module Enscalator
