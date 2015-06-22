require 'aws-sdk-core/client'

module Enscalator
  module Templates

    # Ubuntu instance for testing deployment configuration
    class TestEC2Instance < Enscalator::EnAppTemplateDSL
      include Enscalator::Plugins::Ubuntu
      include Enscalator::Plugins::Elb
      include Enscalator::Helpers

      def tpl
        warn '[Warning] Deploying testing instance, do NOT rely on it to run some code'

        @key_name = 'testbox'
        @instance_name = 'TestBox'

        pre_run do
          basic_setup
          # create ssh public/private keypair, save private key for the local user
          create_ssh_key @key_name, region, force_create: true
        end

        description 'Instance to test enscalator setup/deployment'

        parameter "Ubuntu#{@instance_name}KeyName",
                  :Default => @key_name,
                  :Description => 'Keypair name',
                  :Type => 'String'

        ubuntu_init @instance_name, storage: :'instance-store'

        elb_init stack_name,
                 region,
                 zone_name: hosted_zone

        # Provide public ip for instance
        resource "Ubuntu#{@instance_name}PublicIpAddress",
                 :Type => 'AWS::EC2::EIP',
                 :Properties => {
                   :InstanceId => ref("Ubuntu#{@instance_name}")
                 }
      end
    end
  end
end
