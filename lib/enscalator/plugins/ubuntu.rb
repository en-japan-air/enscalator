require 'open-uri'

module Enscalator
  class Ubuntu
    def self.mapping_ami
      @@amis ||=
        begin
          body = open('https://cloud-images.ubuntu.com/query/trusty/server/released.current.txt') {|f| f.read}
          mapping = {}
          body.split("\n").map{|x| x.split("\t")}
                          .select{|x| x[4] == 'ebs' && x[10] == 'paravirtual'}
                          .map{|x| (mapping[x[6]] ||= {})[x[5]] = x[7]}
          mapping.with_indifferent_access
        end
=begin
      {
        :'us-east-1' => { :i386 => 'ami-56fbaf3e', :amd64 => 'ami-8cecb8e4' },
        :'ap-northeast-1' => { :i386 => 'ami-4b7d9c4b', :amd64 => 'ami-bb7c9dbb' },
        :'eu-west-1' => { :i386 => 'ami-cdaa3fba', :amd64 => 'ami-b556c3c2' },
        :'ap-southeast-1' => { :i386 => 'ami-0c24105e', :amd64 => 'ami-a62410f4' },
        :'ap-southeast-2' => { :i386 => 'ami-952e58af', :amd64 => 'ami-212c5a1b' },
        :'us-west-2' => { :i386 => 'ami-31012601', :amd64 => 'ami-fd0027cd' },
        :'us-west-1' => { :i386 => 'ami-3af8e27f', :amd64 => 'ami-c6f9e383' },

        :'eu-central-1' => { :i386 => 'ami-0a407217', :amd64 => 'ami-5040724d' },
        :'sa-east-1' => { :i386 => 'ami-e7b30dfa', :amd64 => 'ami-c7b10fda' },
      }
=end
    end
  end
end
