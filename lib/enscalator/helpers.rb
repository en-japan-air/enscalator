require_relative 'helpers/sub_process'
require_relative 'helpers/wrappers'
require_relative 'helpers/stack'
require_relative 'helpers/dns'

# Enscalator
module Enscalator
  # Default directory to save generated assets like ssh keys, configs and etc.
  ASSETS_DIR = File.join(ENV['HOME'], ".#{name.split('::').first.downcase}")

  # Collection of helper classes and static methods
  module Helpers
    include Wrappers
    include Stack
    include Dns

    # Initialize enscalator directory
    # @return [String]
    def init_assets_dir
      FileUtils.mkdir_p(Enscalator::ASSETS_DIR) unless Dir.exist?(Enscalator::ASSETS_DIR)
    end

    # Provision Aws.config with custom settings
    # @param [String] region valid aws region
    # @param [String] profile_name aws credentials profile name
    def init_aws_config(region, profile_name: nil)
      fail ArgumentError, 'Unable to proceed without region' if region.blank?
      opts = {}
      opts[:region] = region
      opts[:credentials] = Aws::SharedCredentials.new(profile_name: profile_name) unless profile_name.blank?
      Aws.config.update(opts)
    end

    # Find ami images registered
    #
    # @param [Aws::EC2::Client] client instance of AWS EC2 client
    # @return [Hash] images satisfying query conditions
    # @raise [ArgumentError] when client is not provided or its not expected class type
    def find_ami(client, owners: ['self'], filters: nil)
      fail ArgumentError, 'must be instance of Aws::EC2::Client' unless client.instance_of?(Aws::EC2::Client)
      query = {}
      query[:dry_run] = false
      query[:owners] = owners if owners.is_a?(Array) && owners.any?
      query[:filters] = filters if filters.is_a?(Array) && filters.any?
      client.describe_images(query)
    end

    # Generate ssh keyname from app_name, region and stack name
    #
    # @param [String] app_name application name
    # @param [String] region aws region
    # @param [String] stack_name cloudformation stack name
    def gen_ssh_key_name(app_name, region, stack_name)
      [app_name, region, stack_name].map(&:underscore).join('_')
    end

    # Create ssh public/private key pair, save private key for current user
    #
    # @param [String] key_name key name
    # @param [String] region aws region
    # @param [Boolean] force_create force to create a new ssh key
    def create_ssh_key(key_name, region, force_create: false)
      # Ignoring attempts to generate new ssh key when not deploying
      if @options && @options[:expand]
        warn '[Warning] SSH key can be generated only for create or update stack actions'
        return
      end

      client = ec2_client(region)
      aws_profile = if Aws.config.key?(:credentials)
                      creds = Aws.config[:credentials]
                      creds.profile_name if creds.respond_to?(:profile_name)
                    end
      target_dir = File.join(Enscalator::ASSETS_DIR, aws_profile ? aws_profile : 'default')
      FileUtils.mkdir_p(target_dir) unless Dir.exist? target_dir
      if !client.describe_key_pairs.key_pairs.collect(&:key_name).include?(key_name) || force_create
        # delete existed ssh key
        client.delete_key_pair(key_name: key_name)

        # create a new ssh key
        key_pair = client.create_key_pair(key_name: key_name)
        STDERR.puts "Created new ssh key with fingerprint: #{key_pair.key_fingerprint}"

        # save private key for current user
        private_key = File.join(target_dir, key_name)
        File.open(private_key, 'w') do |wfile|
          wfile.write(key_pair.key_material)
        end
        STDERR.puts "Saved created key to: #{private_key}"
        File.chmod(0600, private_key)
      else
        key_fingerprint =
          begin
            Aws::EC2::KeyPair.new(key_name, client: client).key_fingerprint
          rescue NotImplementedError
            # TODO: after upgrade of aws-sdk use only Aws::EC2::KeyPairInfo
            Aws::EC2::KeyPairInfo.new(key_name, client: client).key_fingerprint
          end
        STDERR.puts "Found existing ssh key with fingerprint: #{key_fingerprint}"
      end
    end

    # Read user data from file
    #
    # @param [String] app_name application name
    def read_user_data(app_name)
      user_data_path = File.join(File.expand_path('..', __FILE__), 'plugins', 'user-data', app_name)
      fail("User data path #{user_data_path} not exists") unless File.exist?(user_data_path)
      File.read(user_data_path)
    end

    # Convert hash with nested values to flat hash
    #
    # @param [Hash] input that should be flatten
    def flatten_hash(input)
      input.each_with_object({}) do |(k, v), h|
        if v.is_a?(Hash)
          flatten_hash(v).map do |h_k, h_v|
            h["#{k}.#{h_k}".to_sym] = h_v
          end
        else
          h[k] = v
        end
      end
    end
  end # module Helpers
end # module Enscalator
