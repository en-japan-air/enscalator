module Enscalator

  # Namespace for enscalator plugins
  module Plugins

    # RethinkDB appliance
    class RethinkDB

      class << self
        OWNER_ID = '679593333241'

        def get_mapping
        end

        # client = Aws::EC2::Client.new(region: 'us-east-1')
        # client.describe_images(dry_run: false, owners: ['679593333241'], filters: [{:name => 'description', :values => ['RethinkDB']}])
      end

      # Mapping for Rethinkdb x64 images
      def self.mapping_amd64
        {
          :'us-east-1' => {
            :'amd64' => 'ami-0cd24e64'
          },
          :'us-west-2' => {
            :'amd64' => 'ami-4592c675'
          },
          :'us-west-1' => {
            :'amd64' => 'ami-7f6d7d3a'
          },
          :'eu-west-1' => {
            :'amd64' => 'ami-7a40f00d'
          },
          :'ap-southeast-1' => {
            :'amd64' => 'ami-1f406d4d'
          },
          :'ap-southeast-2' => {
            :'amd64' => 'ami-b9325b83'
          },
          :'ap-northeast-1' => {
            :'amd64' => 'ami-90c3c491'
          },
          :'sa-east-1' => {
            :'amd64' => 'ami-b38b3aae'
          }
        }
      end

    end # RethinkDB
  end # Plugins
end # Enscalator
