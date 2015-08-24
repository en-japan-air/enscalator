module Enscalator
  module Plugins
    # Ubuntu appliance
    module Ubuntu
      class << self
        # Supported storage types in AWS
        STORAGE = [:ebs, :'ebs-io1', :'ebs-ssd', :'instance-store']

        # Supported Ubuntu image architectures
        ARCH = [:amd64, :i386]

        # Supported Ubuntu releases
        RELEASE = {
          vivid: '15.04',
          utopic: '14.10',
          trusty: '14.04',
          saucy: '13.10',
          raring: '13.04',
          quantal: '12.10',
          precise: '12.04'
        }

        # Structure to hold parsed record
        Struct.new('Ubuntu', :name, :edition, :state, :timestamp, :root_storage, :arch, :region, :ami, :virtualization)

        # Get mapping for Ubuntu images
        #
        # @param [Symbol, String] release a codename or version number
        # @param [Symbol] storage storage kind
        # @param [Symbol] arch architecture
        # @raise [ArgumentError] if release is nil, empty or not one of supported values
        # @raise [ArgumentError] if storage is nil, empty or not one of supported values
        # @raise [ArgumentError] if arch is nil, empty or not one of supported values
        # @return [Hash] mapping for Ubuntu amis
        def get_mapping(release: :trusty, storage: :ebs, arch: :amd64)
          fail ArgumentError, 'release can be either codename or version' unless RELEASE.to_a.flatten.include? release
          fail ArgumentError, "storage can only be one of #{STORAGE}" unless STORAGE.include? storage
          fail ArgumentError, "arch can only be one of #{ARCH}" unless ARCH.include? arch
          begin
            version = RELEASE.keys.include?(release) ? release : RELEASE.key(release)
            body = open("https://cloud-images.ubuntu.com/query/#{version}/server/released.current.txt") { |f| f.read }
            body.split("\n").map { |m| m.squeeze("\t").split("\t").reject { |r| r.include? 'aki' } }
              .map { |l| Struct::Ubuntu.new(*l) }
              .select { |r| r.root_storage == storage.to_s && r.arch == arch.to_s }
              .group_by(&:region)
              .map { |k, v| [k, v.map { |i| [i.virtualization, i.ami] }.to_h] }
              .to_h
              .with_indifferent_access
          end
        end
      end # class << self

      # Create new Ubuntu instance
      #
      # @param [String] instance_name instance name
      # @param [String] storage storage kind (ebs or ephemeral)
      # @param [String] arch architecture (amd64 or i386)
      # @param [String] instance_type instance type
      def ubuntu_init(instance_name,
                      storage: :ebs,
                      arch: :amd64,
                      instance_type: 't2.medium')

        mapping 'AWSUbuntuAMI', Ubuntu.get_mapping(storage: storage, arch: arch)

        parameter_allocated_storage "Ubuntu#{instance_name}",
                                    default: 5,
                                    min: 5,
                                    max: 1024

        parameter_ec2_instance_type "Ubuntu#{instance_name}", type: instance_type

        instance_vpc "Ubuntu#{instance_name}",
                     find_in_map('AWSUbuntuAMI', ref('AWS::Region'), 'hvm'),
                     ref_application_subnets.first,
                     [ref_private_security_group, ref_application_security_group],
                     dependsOn: [],
                     properties: {
                       KeyName: ref("Ubuntu#{instance_name}KeyName"),
                       InstanceType: ref("Ubuntu#{instance_name}InstanceType")
                     }
      end
    end # Ubuntu
  end # Plugins
end # Enscalator
