module Enscalator

  module Plugins

    # RethinkDB appliance
    class RethinkDB

      # Mapping for Rethinkdb x64 images
      def self.mapping
        {
          :'eu-central-1' => {
            :paravirtual => 'ami-1249740f'
          },
          :'eu-west-1' => {
            :paravirtual => 'ami-7a40f00d'
          },
          :'ap-northeast-1' => {
            :paravirtual => 'ami-90c3c491'
          },
          :'us-east-1' => {
            :paravirtual => 'ami-6ea9fb06'
          },
          :'us-west-1' => {
            :paravirtual => 'ami-7f6d7d3a'
          },
          :'us-west-2' => {
            :paravirtual => 'ami-cf0d2cff'
          },
          :'ap-southeast-1' => {
            :paravirtual => 'ami-aa5b6cf8'
          },
          :'ap-southeast-2' => {
            :paravirtual => 'ami-b9325b83'
          },
          :'sa-east-1' => {
            :paravirtual => 'ami-b38b3aae'
          }
        }.with_indifferent_access
      end

    end # RethinkDB
  end # Plugins
end # Enscalator