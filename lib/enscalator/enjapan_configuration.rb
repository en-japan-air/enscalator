module Enscalator

  # Configuration specific for enJapan setup
  class EnJapanConfiguration

    # VPC network mapping
    def self.mapping_vpc_net
      {
        :'us-east-1' => {:VPC => '10.0.0.0/16', :Public1 => '10.0.0.0/24', :Public2 => '10.0.4.0/24'},
        :'us-west-1' => {:VPC => '10.16.0.0/16', :Public1 => '10.16.0.0/24', :Public2 => '10.16.4.0/24'},
        :'us-west-2' => {:VPC => '10.8.0.0/16', :Public1 => '10.8.0.0/24', :Public2 => '10.8.4.0/24'},
        :'eu-west-1' => {:VPC => '10.24.0.0/16', :Public1 => '10.24.0.0/24', :Public2 => '10.24.4.0/24'},
        :'eu-central-1' => {:VPC => '10.32.0.0/16', :Public1 => '10.32.0.0/24', :Public2 => '10.32.4.0/24'},
        :'ap-southeast-1' => {:VPC => '10.40.0.0/16', :Public1 => '10.40.0.0/24', :Public2 => '10.40.4.0/24'},
        :'ap-northeast-1' => {:VPC => '10.48.0.0/16', :Public1 => '10.48.0.0/24', :Public2 => '10.48.4.0/24'},
        :'ap-southeast-2' => {:VPC => '10.56.0.0/16', :Public1 => '10.56.0.0/24', :Public2 => '10.56.4.0/24'},
        :'sa-east-1' => {:VPC => '10.64.0.0/16', :Public1 => '10.64.0.0/24', :Public2 => '10.64.4.0/24'}
      }
    end

    # VPC availability zones mapping
    def self.mapping_availability_zones
      {
        :'us-east-1' => {'AZ' => ['us-east-1a', 'us-east-1b', 'us-east-1c', 'us-east-1e']},
        :'us-west-1' => {'AZ' => ['us-west-1a', 'us-west-1c']},
        :'us-west-2' => {'AZ' => ['us-west-2a', 'us-west-2b', 'us-west-2c']},
        :'eu-west-1' => {'AZ' => ['eu-west-1a', 'eu-west-1b', 'eu-west-1c']},
        :'eu-central-1' => {'AZ' => ['eu-central-1a', 'eu-central-1b']},
        :'ap-northeast-1' => {'AZ' => ['ap-northeast-1a', 'ap-northeast-1c']},
        :'ap-southeast-1' => {'AZ' => ['ap-southeast-1a', 'ap-southeast-1b']},
        :'ap-southeast-2' => {'AZ' => ['ap-southeast-2a', 'ap-southeast-2b']},
        :'sa-east-1' => {'AZ' => ['sa-east-1a', 'sa-east-1b', 'sa-east-1c']}
      }
    end
  end
end
