module Helpers
  # Common asserts
  module Asserts
    # Regions supported by Amazon AWS
    AWS_REGIONS = %w(
      eu-central-1 ap-northeast-1 sa-east-1 ap-southeast-2 ap-southeast-1 us-east-1 us-west-2 us-west-1 eu-west-1
    )

    # Virtualization support by Amazon AWS
    AWS_VIRTUALIZATION = {
      :hvm => 'hvm',
      :pv => 'paravirtual'
    }

    def assert_mapping(mapping, fields: [])
      if mapping.keys.map(&:class).uniq.shift == Symbol
        assert_regions(mapping.keys, AWS_REGIONS.map(&:to_sym))
      elsif mapping.keys.map(&:class).uniq.shift == String
        assert_regions(mapping.keys, AWS_REGIONS)
      end

      mapping.values.each do |v|
        expected = fields && fields.empty? ? AWS_VIRTUALIZATION.keys.map(&:to_s) : fields
        expect(v.keys.size).to be <= expected.size
        expect(v.keys).to include(expected.first).or include(expected.last)
      end

      mapping.values.map(&:values).flatten.each do |ami|
        assert_ami(ami)
      end
    end

    def assert_regions(actual, valid)
      expect(actual).to satisfy { |a| (valid - a).size >= 0 }
    end

    def assert_ami(str)
      expect(str).to match Regexp.new(/ami[-][a-z0-9]{8}/)
    end

    def assert_ec2_instance_type(type)
      expect(type).to match Regexp.new(/^[\w\d]{1,3}[.][\w]*$/)
    end

    def assert_rds_instance_type(type)
      expect(type).to match Regexp.new(/^db[.][\w\d]{1,3}[.][\w]*$/)
    end

    def assert_el_cache_instance_type(type)
      expect(type).to match Regexp.new(/^cache[.][\w\d]{1,3}[.][\w]*$/)
    end
  end # Asserts
end # Helpers
