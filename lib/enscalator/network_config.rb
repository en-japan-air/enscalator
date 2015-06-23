# -*- encoding : utf-8 -*-

module Enscalator

  # Configuration specific for VPC setup
  class NetworkConfig

    # VPC network mapping
    def self.mapping_vpc_net
      {
        :'us-east-1' => {VPC: '10.0.0.0/16'},
        :'us-west-1' => {VPC: '10.16.0.0/16'},
        :'us-west-2' => {VPC: '10.8.0.0/16'},
        :'eu-west-1' => {VPC: '10.24.0.0/16'},
        :'eu-central-1' => {VPC: '10.32.0.0/16'},
        :'ap-southeast-1' => {VPC: '10.40.0.0/16'},
        :'ap-northeast-1' => {VPC: '10.48.0.0/16'},
        :'ap-southeast-2' => {VPC: '10.56.0.0/16'},
        :'sa-east-1' => {VPC: '10.64.0.0/16'}
      }
    end
  end
end
