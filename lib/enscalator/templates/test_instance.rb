require 'aws-sdk-core/client'

module Enscalator
  module Templates
    class TestEC2Instance < Enscalator::EnAppTemplateDSL

      include Enscalator::Plugins::Ubuntu

      def tpl
        warn '[Warning] Deploying testing instance, do NOT rely on it to run some code'

        @key_name = 'testbox'
        @instance_name = 'TestBox'

        pre_run do
          pre_setup stack_name: 'test-vpc',
                    region: @options[:region],
                    start_ip_idx: 32
        end

        # create ssh public/private keypair, save private key for the local user
        pre_run do
          private_key_file = File.join(ENV['HOME'], '.ssh', @key_name)
          client = Aws::EC2::Client.new region: @options[:region]

          if File.exists?(private_key_file)
            key_pair_client = Aws::EC2::KeyPair.new(@key_name, client: client)

            # remove key if one with same name was already uploaded
            if key_pair_client.key_name == @key_name
              # TODO: find sane and working way to calculate fingerprint of local private key
              client.delete_key_pair dry_run: false, key_name: @key_name
              File.unlink(private_key_file)
            else
              # create new key
              @key_pair = client.create_key_pair dry_run: false, key_name: @key_name
              File.open(private_key_file, 'w') do |wfile|
                wfile.write(@key_pair.key_material)
              end
              File.chmod(0600, private_key_file)
              puts %Q{Created new ssh key with fingerprint: #{@key_pair.key_fingerprint}}
            end
          end
        end

        description 'Instance to test enscalator setup/deployment'

        parameter "Ubuntu#{@instance_name}KeyName",
                  :Default => @key_name,
                  :Description => 'Keypair name',
                  :Type => 'String'

        ubuntu_init @instance_name,
                    storage_kind: 'ebs',
                    virtualization: 'paravirtual',
                    allocate_public_ip: true

      end
    end
  end
end
