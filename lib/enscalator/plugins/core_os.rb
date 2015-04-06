# encoding: UTF-8

module Enscalator
  module Plugins
    module CoreOS

      # Initialize CoreOS related configurations
      #
      def core_os_init

        # TODO: download ami mapping dynamically
        mapping 'AWSCoreOSAMI',
                {
                  :'eu-central-1' => {:hvm => 'ami-0e300d13'},
                  :'ap-northeast-1' => {:hvm => 'ami-6a7b676b'},
                  :'sa-east-1' => {:hvm => 'ami-2354ec3e'},
                  :'ap-southeast-2' => {:hvm => 'ami-b9b5c583'},
                  :'ap-southeast-1' => {:hvm => 'ami-f80b3aaa'},
                  :'us-east-1' => {:hvm => 'ami-323b195a'},
                  :'us-west-2' => {:hvm => 'ami-0789a437'},
                  :'us-west-1' => {:hvm => 'ami-8dd533c9'},
                  :'eu-west-1' => {:hvm => 'ami-55950a22'}
                }

      end

    end # module CoreOS
  end # module Plugins
end # module Enscalator
