module TestHelpers

  AWS_REGIONS = %w{eu-central-1 ap-northeast-1 sa-east-1 ap-southeast-2
                ap-southeast-1 us-east-1 us-west-2 us-west-1 eu-west-1}

  AWS_VIRTUALIZATION = {
      :hvm => 'hvm',
      :pv => 'paravirtual'
  }

  def assert_mapping(mapping, fields: [])
    expect(mapping.keys).to include(*AWS_REGIONS)
    mapping.values.each do |v|
      expected = fields && fields.empty? ? AWS_VIRTUALIZATION.keys : fields
      expect(v).to include(*expected)
    end
    mapping.values.map(&:values).flatten.each do |ami|
      assert_ami(ami)
    end
  end

  def assert_ami(str)
    expect(str).to match /ami[-][a-z0-9]{8}/
  end
end