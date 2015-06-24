module Enscalator

  module Plugins

    # Debian appliance
    class Debian

      class << self

        def get_mapping(storage: '', arch: '')
        end

      end

      # Create new Debian instance
      #
      # @param [String] storage storage kind (usually ebs or ephemeral)
      # @param [String] arch architecture (amd64 or i386)
      def debian_init(storage: :'ebs',
                      arch: :amd64)
        mapping 'DebianAMI', Debian.get_mapping(storage: storage, arch: arch)
      end

    end # class Debian
  end # module Plugins
end # module Enscalator