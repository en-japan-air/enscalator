
module Enscalator
  class EnJapanConfiguration
    def self.mapping_vpc_net
      {
        'us-east-1' => { :VPC => '10.0.0.0/16', :Public1 => '10.0.0.0/24', :Public2 => '10.0.4.0/24' },
        'us-west-2' => { :VPC => '10.8.0.0/16', :Public1 => '10.8.0.0/24', :Public2 => '10.8.4.0/24' },
        'us-west-1' => { :VPC => '10.16.0.0/16', :Public1 => '10.16.0.0/24', :Public2 => '10.16.4.0/24' },
        'eu-west-1' => { :VPC => '10.24.0.0/16', :Public1 => '10.24.0.0/24', :Public2 => '10.24.4.0/24' },
        'eu-central-1' => { :VPC => '10.32.0.0/16', :Public1 => '10.32.0.0/24', :Public2 => '10.32.4.0/24' },
        'ap-southeast-1' => { :VPC => '10.40.0.0/16', :Public1 => '10.40.0.0/24', :Public2 => '10.40.4.0/24' },
        'ap-northeast-1' => { :VPC => '10.48.0.0/16', :Public1 => '10.48.0.0/24', :Public2 => '10.48.4.0/24' },
        'ap-southeast-2' => { :VPC => '10.56.0.0/16', :Public1 => '10.56.0.0/24', :Public2 => '10.56.4.0/24' },
        'sa-east-1' => { :VPC => '10.64.0.0/16', :Public1 => '10.64.0.0/24', :Public2 => '10.64.4.0/24' }
      }
    end
  end
end
