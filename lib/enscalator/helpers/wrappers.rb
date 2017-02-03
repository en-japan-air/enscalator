module Enscalator
  module Helpers
    # Helpers that wrap some
    module Wrappers
      # Cloudformation client
      #
      # @param [String] region Region in Amazon AWS
      # @return [Aws::CloudFormation::Client]
      # @raise [ArgumentError] when region is not given
      def cfn_client(region)
        fail ArgumentError, 'Unable to proceed without region' if region.blank? && !Aws.config.key?(:region)
        opts = {}
        opts[:region] = region unless Aws.config.key?(:region)
        Aws::CloudFormation::Client.new(opts)
      end

      # EC2 client
      #
      # @param [String] region Region in Amazon AWS
      # @return [Aws::EC2::Client]
      # @raise [ArgumentError] when region is not given
      def ec2_client(region)
        fail ArgumentError, 'Unable to proceed without region' if region.blank? && !Aws.config.key?(:region)
        opts = {}
        opts[:region] = region unless Aws.config.key?(:region)
        # noinspection RubyArgCount
        Aws::EC2::Client.new(opts)
      end

      # Route 53 client
      #
      # @param [String] region AWS region identifier
      # @return [Aws::Route53::Client]
      # @raise [ArgumentError] when region is not given
      def route53_client(region)
        fail ArgumentError, 'Unable to proceed without region' if region.blank? && !Aws.config.key?(:region)
        opts = {}
        opts[:region] = region unless Aws.config.key?(:region)
        # noinspection RubyArgCount
        Aws::Route53::Client.new(opts)
      end

      # Cloudformation resource
      #
      # @param [Aws::CloudFormation::Client] client instance of AWS Cloudformation client
      # @return [Aws::CloudFormation::Resource]
      # @raise [ArgumentError] when client is not provided or its not expected class type
      def cfn_resource(client)
        fail ArgumentError,
             'must be instance of Aws::CloudFormation::Client' unless client.instance_of?(Aws::CloudFormation::Client)
        Aws::CloudFormation::Resource.new(client: client)
      end
    end
  end
end
