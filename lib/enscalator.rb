require 'trollop'
require 'ipaddr'
require 'ipaddress'
require 'digest'
require 'aws-sdk'
require 'active_support'
require 'active_support/core_ext'
require 'active_support/inflector'
require 'active_support/inflector/inflections'
require 'enscalator/version'
require 'enscalator/helpers'
require 'enscalator/core'
require 'enscalator/plugins'
require 'enscalator/richtemplate'
require 'enscalator/vpc_with_nat_gateway'
require 'enscalator/vpc_with_nat_instance'
require 'enscalator/vpc'
require 'enscalator/enapp'
require 'enscalator/templates'

# Namespace for Enscalator related code
module Enscalator
  # Main method to actually run Enscalator
  # @param [Array] argv list of command-line arguments
  def self.run!(argv)
    argv_dup = argv.dup
    display_name = name.downcase
    parser = Trollop::Parser.new do
      banner "Usage: #{display_name} [arguments]"

      opt :list_templates, 'List all available templates', default: false, short: 'l'
      opt :template, 'Template name', type: String, short: 't'
      opt :template_file, 'Template filename', type: String, short: 'f'
      opt :region, 'AWS Region', type: String, default: 'us-east-1', short: 'r'
      opt :parameters, "Parameters 'Key1=Value1;Key2=Value2'", type: String, short: 'p'
      opt :stack_name, 'Stack name', type: String, short: 's'
      opt :private_hosted_zone, "Private hosted zone (e.x. 'enjapan.prod.')", type: String, short: 'z'
      opt :public_hosted_zone, 'Public hosted zone', type: String, short: 'g'
      opt :create_stack, 'Create the stack', default: false, short: 'c'
      opt :update_stack, 'Update already deployed stack', default: false, short: 'u'
      opt :pre_run, 'Use pre-run hooks', default: true, short: 'e'
      opt :post_run, 'Use post-run hooks', default: true, short: 'o'
      opt :expand, 'Print generated JSON template', default: false, short: 'x'
      opt :capabilities, 'AWS capabilities', default: 'CAPABILITY_IAM', short: 'a'
      opt :vpc_stack_name, 'VPC stack name', default: 'enjapan-vpc', short: 'n'
      opt :availability_zone, 'Deploy to specific availability zone', default: 'all', short: 'd'
      opt :profile, 'Use a specific profile from your credential file', type: String, default: nil

      conflicts :list_templates, :create_stack, :update_stack, :expand
    end

    opts = Trollop.with_standard_exception_handling(parser) do
      fail Trollop::HelpNeeded if argv.empty?
      parser.parse argv
    end

    if opts[:availability_zone_given]
      valid_values = ('a'..'e').to_a << 'all'
      unless valid_values.include? opts[:availability_zone]
        STDERR.puts %(Availability zone can be only one off "#{valid_values.join(',')}")
        exit
      end
    end

    # load template from given file and update template list
    if opts[:template_file]
      unless File.exist?(opts[:template_file])
        abort('Unable to find file "%s"' % opts[:template_file])
      end
      load(opts[:template_file])
      unless Enscalator::Templates.all_valid?
        STDERR.puts 'Some templates missing required tpl method:'
        Enscalator::Templates.all.select { |a| !a.instance_methods.include?(:tpl) }.each do |tpl|
          STDERR.puts tpl.name.demodulize
        end
        exit
      end
    end

    templates = Enscalator::Templates.constants.map(&:to_s)

    if opts[:list_templates]
      STDERR.puts 'Available templates:'
      STDERR.puts templates.sort
      exit
    end

    if opts[:template] && templates.include?(opts[:template])
      # for stack_name use template name as a base and convert it from camelcase to underscore case
      opts[:stack_name] ||= opts[:template].underscore.gsub(/[_]/, '-')
      Object.const_get("Enscalator::Templates::#{opts[:template]}").new(opts.merge(ARGV: argv_dup)).exec!
    elsif opts[:template_given] && !opts[:template].empty?
      STDERR.puts %(Template "#{opts[:template]}" doesn't exist)
    else
      STDERR.puts 'Template name cannot be an empty string'
    end
  end
end
