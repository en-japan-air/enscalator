module TestHelpers

  AWS_REGIONS = %w{eu-central-1 ap-northeast-1 sa-east-1 ap-southeast-2
                ap-southeast-1 us-east-1 us-west-2 us-west-1 eu-west-1}

  def assert_mapping(mapping)
    expect(mapping.keys).to include(*AWS_REGIONS)
    mapping.values.each do |v|
      expect(v).to include(*[:hvm, :pv])
    end
    mapping.values.map(&:values).flatten.each do |ami|
      expect(ami).to match /ami[-][a-z0-9]{8}/
    end
  end
end