module Enscalator

  # Instance type
  module InstanceType

    # Generic Aws instance
    class AwsInstance
      attr :current_generation, :previous_generation

      # Create new AwsInstance
      #
      # @param [Hash] current generation instances
      # @param [Hash] previous generation instances
      def initialize(current = {}, previous = {})
        fail('Unable to instantiate if its not Hash') unless current.is_a?(Hash) && previous.is_a?(Hash)
        @current_generation ||= current
        @previous_generation ||= previous
      end

      # Check if given instance type is included in either current or previous generation
      #
      # @param [String] type instance type
      # @return [Boolean]
      def verify(type)
        current_generation.values.dup.concat(previous_generation.values).flatten.include? type
      end
    end

    # EC2 instance
    class EC2 < AwsInstance

      def initialize
        super(current_generation, previous_generation)
      end

      # Current generation instance types
      #
      # @return [Hash] instance family and type
      def current_generation
        {
          general_purpose: %w{ t2.micro t2.small t2.medium t2.large
                             m4.large m4.xlarge m4.2xlarge m4.4xlarge m4.10xlarge
                             m3.medium m3.large m3.xlarge m3.2xlarge },
          compute_optimized: %w{ c4.large c4.xlarge c4.2xlarge c4.4xlarge c4.8xlarge
                               c3.large c3.xlarge c3.2xlarge c3.4xlarge c3.8xlarge },
          memory_optimized: %w{ r3.large r3.xlarge r3.2xlarge r3.4xlarge r3.8xlarge },
          gpu: %w{ g2.2xlarge g2.8xlarge },
          high_io_optimized: %w{ i2.xlarge i2.xlarge i2.4xlarge i2.8xlarge },
          dense_storage_optimized: %w{ d2.xlarge d2.2xlarge d2.4xlarge d2.8xlarge }
        }
      end

      # @deprecated Will be removed once Amazon fully stops supporting these instances
      # Previous generation instance types
      #
      # @return [Hash] instance family and type
      def previous_generation
        {
          general_purpose: %w{ m1.small m1.medium m1.large m1.xlarge },
          compute_optimized: %w{ c1.medium c1.xlarge cc2.8xlarge },
          gpu: %w{ cg1.4xlarge },
          memory_optimized: %w{ m2.xlarge m2.2xlarge m2.4xlarge cr1.8xlarge },
          storage_optimized: %w{ hi1.4xlarge hs1.8xlarge },
          micro: %w{ t1.micro }
        }
      end
    end

    # RDS instance
    class RDS < AwsInstance

      def initialize
        super(current_generation, previous_generation)
      end

      # Current generation instance types
      #
      # @return [Hash] instance family and type
      def current_generation
        {
          standard: %w{ db.m3.medium db.m3.large db.m3.xlarge db.m3.2xlarge },
          memory_optimized: %w{ db.r3.large db.r3.xlarge db.r3.2xlarge db.r3.4xlarge db.r3.8xlarge },
          burstable_performance: %w{ db.t2.micro db.t2.small db.t2.medium }
        }
      end

      # @deprecated Will be removed once Amazon fully stops supporting these instances
      # Previous generation instance types
      #
      # @return [Hash] instance family and type
      def previous_generation
        {
          standard: %w{ db.m1.small db.m1.medium db.m1.large db.m1.xlarge },
          memory_optimized: %w{ db.m2.xlarge db.m2.2xlarge db.m2.4xlarge db.cr1.8xlarge },
          micro: %w{ db.t1.micro }
        }
      end

    end

    # Simple interface to directly access classes above using module methods
    class << self

      # Creates EC2 instance type with corresponding values set
      #
      # @return [Enscalator::InstanceType::EC2]
      def ec2_instance_type
        EC2.new
      end

      # Creates RDS instance type with corresponding values set
      #
      # @return [Enscalator::InstanceType::RDS]
      def rds_instance_type
        RDS.new
      end

    end

  end # module InstanceType

end # module Enscalator