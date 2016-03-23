module Enscalator
  module Plugins
    # Elasticsearch related configuration
    module ElasticsearchOpsworks
      include Enscalator::Plugins::Elb

      # Create Elasticsearch cluster using Opsworks
      #
      # @param [String] app_name application name
      # @param [String] ssh_key name of the ssh key
      # @param [String] os base operating system
      # @param [String] cookbook chef cookbook
      def elasticsearch_init(app_name,
                             ssh_key:,
                             es_config: {},
                             os: 'Amazon Linux 2015.09',
                             cookbook: 'https://github.com/en-japan/opsworks-elasticsearch-cookbook.git')

        parameter "ES#{app_name}ChefCookbook",
                  Default: cookbook,
                  Description: 'GitURL',
                  Type: 'String'

        parameter "ES#{app_name}InstanceDefaultOs",
                  Default: os,
                  Description: ['The stack\'s default operating system, which is installed',
                                'on every instance unless you specify a different',
                                'operating system when you create the instance.'].join(' '),
                  Type: 'String'

        parameter "ES#{app_name}SshKeyName",
                  Default: ssh_key,
                  Description: 'SSH key name for EC2 instances.',
                  Type: 'String'

        resource 'InstanceRole',
                 Type: 'AWS::IAM::InstanceProfile',
                 Properties: {
                   Path: '/',
                   Roles: [
                     ref('OpsWorksEC2Role')
                   ]
                 }

        resource 'ServiceRole',
                 Type: 'AWS::IAM::Role',
                 Properties: {
                   AssumeRolePolicyDocument: {
                     Statement: [
                       {
                         Effect: 'Allow',
                         Principal: {
                           Service: [
                             'opsworks.amazonaws.com'
                           ]
                         },
                         Action: [
                           'sts:AssumeRole'
                         ]
                       }
                     ]
                   },
                   Path: '/',
                   Policies: [
                     {
                       PolicyName: "#{app_name}-opsworks-service",
                       PolicyDocument: {
                         Statement: [
                           {
                             Effect: 'Allow',
                             Action: %w( ec2:* iam:PassRole cloudwatch:GetMetricStatistics elasticloadbalancing:* ),
                             Resource: '*'
                           }
                         ]
                       }
                     }
                   ]
                 }

        resource 'OpsWorksEC2Role',
                 Type: 'AWS::IAM::Role',
                 Properties: {
                   AssumeRolePolicyDocument: {
                     Statement: [
                       {
                         Effect: 'Allow',
                         Principal: {
                           Service: [
                             'ec2.amazonaws.com'
                           ]
                         },
                         Action: [
                           'sts:AssumeRole'
                         ]
                       }
                     ]
                   },
                   Path: '/',
                   Policies: [
                     {
                       PolicyName: "#{app_name}-opsworks-ec2-role",
                       PolicyDocument: {
                         Statement: [
                           {
                             Effect: 'Allow',
                             Action: %w(
                               ec2:DescribeInstances
                               ec2:DescribeRegions
                               ec2:DescribeSecurityGroups
                               ec2:DescribeTags
                               cloudwatch:PutMetricData),
                             Resource: '*'
                           }
                         ]
                       }
                     }
                   ]
                 }

        instances_security_group = security_group_vpc("ES#{app_name}", 'so that ES cluster can find other nodes', vpc.id)

        ops_stack_name = "#{app_name}-ES"
        resource 'ESStack',
                 Type: 'AWS::OpsWorks::Stack',
                 Properties: {
                   Name: ops_stack_name,
                   VpcId: vpc.id,
                   DefaultSubnetId: ref_resource_subnets.first,
                   ConfigurationManager: {
                     Name: 'Chef',
                     Version: '12'
                   },
                   UseCustomCookbooks: 'true',
                   CustomCookbooksSource: {
                     Type: 'git',
                     Url: ref("ES#{app_name}ChefCookbook")
                   },
                   DefaultOs: ref("ES#{app_name}InstanceDefaultOs"),
                   DefaultRootDeviceType: 'ebs',
                   DefaultSshKeyName: ref("ES#{app_name}SshKeyName"),
                   CustomJson: {
                     java: {
                       jdk_version: '8',
                       oracle: {
                         accept_oracle_download_terms: 'true'
                       },
                       accept_license_agreement: 'true',
                       install_flavor: 'oracle'
                     },
                     elasticsearch: {
                       plugins: [
                         'analysis-kuromoji',
                         'cloud-aws',
                         { name: 'elasticsearch-head', url: 'mobz/elasticsearch-head' }
                       ],
                       config: {
                         'cluster.name': "#{app_name}-elasticsearch",
                         'path.data': '/mnt/elasticsearch-data',
                         'network.bind_host': '0.0.0.0',
                         'network.publish_host': '_non_loopback_',
                         'cloud.aws.region': region,
                         discovery: {
                           type: 'ec2',
                           ec2: {
                             groups: [ref(instances_security_group)],
                             tag: {
                               'opsworks:stack': ops_stack_name
                             }
                           }
                         },
                         'cluster.routing.allocation.awareness.attributes': 'rack_id'
                       }.merge(es_config)
                     }
                   },
                   ServiceRoleArn: {
                     'Fn::GetAtt': %w(ServiceRole Arn)
                   },
                   DefaultInstanceProfileArn: {
                     'Fn::GetAtt': %w(InstanceRole Arn)
                   }
                 }

        resource 'ESLayer',
                 Type: 'AWS::OpsWorks::Layer',
                 Properties: {
                   StackId: ref('ESStack'),
                   Name: 'Search',
                   Type: 'custom',
                   Shortname: 'search',
                   CustomRecipes: {
                     Setup: %w(apt ark java layer-custom::es-opsworks)
                   },
                   EnableAutoHealing: 'true',
                   AutoAssignElasticIps: 'false',
                   AutoAssignPublicIps: 'false',
                   VolumeConfigurations: [
                     {
                       MountPoint: '/mnt/elasticsearch-data',
                       NumberOfDisks: 1,
                       VolumeType: 'gp2',
                       Size: 100
                     }
                   ],
                   CustomSecurityGroupIds: [
                     {
                       'Fn::GetAtt': %W(#{instances_security_group} GroupId)
                     },
                     ref_private_security_group
                   ]
                 }

        resource 'ESMainInstance',
                 Type: 'AWS::OpsWorks::Instance',
                 Properties: {
                   # EbsOptimized: true,          # Not available for m3.medium
                   InstanceType: 'm3.medium',
                   LayerIds: [ref('ESLayer')],
                   StackId: ref('ESStack')
                 }
      end
    end # module Elasticsearch
  end # module Plugins
end # module Enscalator
