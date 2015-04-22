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
          pre_setup stack_name: 'test-vpc',
                    region: @options[:region]
        end

        # create ssh public/private keypair, save private key for the local user
        pre_run do
          create_ssh_key @key_name,
                         @options[:region],
                         force_create: true
        end

        description 'Instance to test enscalator setup/deployment'

        parameter "Ubuntu#{@instance_name}KeyName",
                  :Default => @key_name,
                  :Description => 'Keypair name',
                  :Type => 'String'

        ubuntu_init @instance_name,
                    storage_kind: :'instance-store',
                    virtualization: :hvm,
                    allocate_public_ip: true

        elb_init @options[:stack_name],
                 @options[:region]

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
