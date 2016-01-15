module Enscalator
  module Plugins
    # Amazon Linux appliance
    module AmazonLinux
      class << self
        # Supported storage types in AWS
        STORAGE = [:ebs, :'instance-store']

        # Supported EBS volume types
        EBS_VOLUME_TYPES = [:standard, :gp2]

        # Supported Debian image architectures
        ARCH = [:x86_64, :i386]

        # @param [Symbol, String] release a codename or version number
        # @param [Symbol] storage storage kind
        # @param [Symbol] arch architecture
        # @raise [ArgumentError] if storage is nil, empty or not one of supported values
        # @raise [ArgumentError] if arch is nil, empty or not one of supported values
        # @return [Hash] mapping for Debian amis
        def get_ami(region:, release: '2015.09.1', storage: :ebs, arch: :x86_64, ebs_type: :gp2, filters: {})
          fail ArgumentError, "storage can only be one of #{STORAGE}" unless STORAGE.include? storage
          fail ArgumentError, "arch can only be one of #{ARCH}" unless ARCH.include? arch
          fail ArgumentError, "ebs_type can only be one of #{EBS_VOLUME_TYPES}" unless EBS_VOLUME_TYPES.include? ebs_type

          client = Aws::EC2::Client.new(region: region)

          resp = client.describe_images(
            owners: ['amazon'],
            filters: [
              {
                name: 'name',
                values: ["amzn-ami-hvm-#{release}*", "amzn-ami-pv-#{release}*"]
              },
              {
                name: 'root-device-type',
                values: [storage.to_s]
              },
              {
                name: 'architecture',
                values: [arch.to_s]
              }
            ] + filters_map_to_array(filters)
          )

          err_msg = format('Could not find any Linux Amazon Ami that fits the criteria: %s, %s, %s, %s, %s, %s',
                           region, release, storage, arch, ebs_type, filters)
          fail StandardError, err_msg unless resp.images

          images = resp.images.sort_by(&:creation_date).reverse
          images = images.select { |i| i.block_device_mappings.first.ebs.volume_type == ebs_type.to_s } if storage == :ebs
          images.first.image_id
        end

        private

        def filters_map_to_array(filters)
          filters.map do |k, v|
            {
              name: k.to_s,
              values: v.is_a?(Array) ? v : [v.to_s]
            }
          end
        end
      end

      # Create new Debian instance
      #
      # @param [String] storage storage kind (usually ebs or ephemeral)
      # @param [String] arch architecture (amd64 or i386)
      def amazon_linux_init(region: self.region,
                            release: '2015.09.1',
                            storage: :ebs,
                            arch: :x86_64,
                            ebs_type: :gp2,
                            filters: {})
        parameter_ami 'AmazonLinux', AmazonLinux.get_ami(region: region,
                                                         release: release,
                                                         storage: storage,
                                                         arch: arch,
                                                         ebs_type: ebs_type,
                                                         filters: filters)
      end
    end # class AmazonLinux
  end # module Plugins
end # module Enscalator
