module Enscalator
  class Couchbase
    def self.mapping_ami
      {
        :'us-east-1' => { :amd64 => 'ami-403b4328' },                                                                                                    
        :'us-west-2' => { :amd64 => 'ami-c398c6f3' },
        :'us-west-1' => { :amd64 => 'ami-1a554c5f' },
        :'eu-west-1' => { :amd64 => 'ami-8129aaf6' },
        :'ap-southeast-1' => { :amd64 => 'ami-88745fda' },
        :'ap-northeast-1' => { :amd64 => 'ami-6a7b676b' },
        :'sa-east-1' => { :amd64 => 'ami-59229f44' }
      }
    end
  end
end
