require 'cloudformation-ruby-dsl/cfntemplate'

class RichTemplateDSL < TemplateDSL

  def tags_to_properties(tags)
    tags.map { |k,v| {:Key => k, :Value => v}}
  end

  def vpc(name,cidr, enableDnsSupport:nil, enableDnsHostnames:nil, dependsOn:[], tags:{}) 
    properties = {
      :CidrBlock => cidr,
    }
    properties[:EnableDnsSupport] = enableDnsSupport unless enableDnsSupport.nil?
    properties[:EnableDnsHostnames] = enableDnsHostnames unless enableDnsHostnames.nil?
    unless tags.include?('Name')
      tags['Name'] = join('-', aws_stack_name, name)
    end
    properties[:Tags] = tags_to_properties(tags)
    options = {
      :Type => 'AWS::EC2::VPC',
      :Properties => properties
    }
    options[:DependsOn] = dependsOn unless dependsOn.empty?
    resource name, options
  end


  def subnet(name,vpc,cidr, availabilityZone:'', dependsOn:[], tags:{})
    properties = {
      :VpcId => vpc,
      :CidrBlock => cidr,
    }
    properties[:AvailabilityZone] = availabilityZone unless availabilityZone.empty?
    unless tags.include?('Name')
      tags['Name'] = join('-', aws_stack_name, name)
    end
    properties[:Tags] = tags_to_properties(tags)

    options = {
      :Type => 'AWS::EC2::Subnet',
      :Properties => properties
    }
    options[:DependsOn] = dependsOn unless dependsOn.empty?
    resource name, options
  end


  def security_group(name,description,securityGroupEgress:[], securityGroupIngress:[],dependsOn:[],tags:{})
    properties = {
      :GroupDescription => description
    }
    properties[:SecurityGroupIngress] = securityGroupIngress unless securityGroupIngress.empty?
    properties[:SecurityGroupEgress] = securityGroupEgress unless securityGroupEgress.empty?
    unless tags.include?('Name')
      tags['Name'] = join('-', aws_stack_name, name)
    end
    properties[:Tags] = tags_to_properties(tags)
    options = {
      :Type => 'AWS::EC2::SecurityGroup',
      :Properties => properties
    }
    options[:DependsOn] = dependsOn unless dependsOn.empty?
    resource name, options
  end

  def security_group_vpc(name,description,vpc,securityGroupEgress:[], securityGroupIngress:[],dependsOn:[],tags:{})
    properties = {
      :VpcId => vpc,
      :GroupDescription => description
    }
    properties[:SecurityGroupIngress] = securityGroupIngress unless securityGroupIngress.empty?
    properties[:SecurityGroupEgress] = securityGroupEgress unless securityGroupEgress.empty?
    unless tags.include?('Name')
      tags['Name'] = join('-', aws_stack_name, name)
    end
    properties[:Tags] = tags_to_properties(tags)
    options = {
      :Type => 'AWS::EC2::SecurityGroup',
      :Properties => properties
    }
    options[:DependsOn] = dependsOn unless dependsOn.empty?
    resource name, options
  end

  def network_interface(device_index, options:{})
    options[:DeviceIndex] = device_index
    options
  end

  def instance(name, image_id, subnet, security_groups, dependsOn:[], properties:{})
    raise "Non VPC instance #{name} can not contain NetworkInterfaces" if properties.include?(:NetworkInterfaces)
    raise "Non VPC instance #{name} can not contain VPC SecurityGroups" if properties.include?(:SecurityGroupIds)

  end

  def instance_vpc(name, image_id, subnet, security_groups, dependsOn:[], properties:{})
    raise "VPC instance #{name} can not contain NetworkInterfaces and subnet or security_groups" if properties.include?(:NetworkInterfaces)
    raise "VPC instance #{name} can not contain non VPC SecurityGroups" if properties.include?(:SecurityGroups)
    properties[:SubnetId] = subnet
    properties[:SecurityGroupIds] = security_groups
    options = {
      :Type => 'AWS::EC2::Instance',
      :Properties => properties
    }
    options[:DependsOn] = dependsOn unless dependsOn.empty?
    resource name, options
  end

  def instance_with_network(name,image_id,network_interfaces, properties:{})
    raise "Instance with NetworkInterfaces #{name} can not contain instance subnet or security_groups" if properties.include?(:SubnetId) or properties.include?(:SecurityGroups) or properties.include?(:SecurityGroupIds)
    properties[:NetworkInterfaces] = network_interfaces
    options = {
      :Type => 'AWS::EC2::Instance',
      :Properties => properties
    }
    options[:DependsOn] = dependsOn unless dependsOn.empty?
    resource name, options

  end

end
