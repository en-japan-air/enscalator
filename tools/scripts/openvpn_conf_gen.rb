#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'pathname'
require 'erb'

module OpenVPN
  class ConfigTemplate < ERB
    def self.template
      template = <<TEMPLATE
client
dev tun
proto udp
remote <%= @gateway_addr %> 1194

resolv-retry infinite
nobind
persist-key
persist-tun
mtu-test

ca ca.crt
cert <%= @user_cert %>
key <%= @user_key %>
tls-auth ta.key 1

comp-lzo
verb 3
TEMPLATE
      template
    end

    def initialize(options = {})
      @template = options.fetch(:template, self.class.template)
      options.dup.delete_if { |k, _| k == :template }.each do |k, v|
        instance_variable_set("@#{k}".to_sym, v)
      end
      super(@template)
    end

    def result
      super(binding)
    end

    def save_file(filename)
      File.open(filename, 'w+') { |wfile| wfile.write(result) }
    end
  end

  module Generator
    self.extend(self)

    def opt_parser(argv)
      argv << '-h' if argv.empty?
      options = {}
      opt_parser = OptionParser.new do |opts|
        opts.banner = 'Usage: openvpn_conf_gen [options]'
        options[:keys_dir] = nil
        opts.on('-k', '--keys [DIRECTORY]', String, 'Directory with easyrsa keys') do |k|
          k.nil? ? puts(opt_parser) : options[:keys_dir] = Pathname.new(k)
        end
        options[:username] = nil
        opts.on('-u', '--user [USERNAME]', String, 'Username to use for configuration') do |u|
          u.nil? ? puts(opt_parser) : options[:username] = u
        end
        options[:gateway_addr] = nil
        opts.on('-g', '--gateway [ADDRESS]', String, 'Address of OpenVPN gateway') do |g|
          g.nil? ? puts(opt_parser) : options[:gateway_addr] = g
        end
        opts.on('-h', '--help', 'Show help') do |h|
          options[:help] = h
          puts opt_parser
          exit
        end
      end
      opt_parser.parse(argv)
      options
    end

    # Create dmg file from given directory
    def create_dmg_bundle(volume_name, src_dir, filename)
      cmd = %w(hdiutil create)
      cmd << sprintf("-volname \"%s\"", volume_name)
      cmd << sprintf("-srcfolder \"%s\"", src_dir)
      cmd << '-ov'
      cmd << '-format UDZO'
      cmd << filename
      puts `#{cmd.join(' ')}`
    end

    def runner(options = {})
      work_dir = Pathname.new(Dir.pwd).join('openvpn')
      keys_dir = Pathname.new(options[:keys_dir])
      FileUtils.mkdir_p(work_dir) unless Dir.exists?(work_dir)

      operator = options[:username]
      gateway_addr = options[:gateway_addr]

      puts "Generating OpenVPN configuration bundle for user \"#{operator}\""
      user_config_dir = work_dir.join(operator)
      FileUtils.mkdir_p(user_config_dir) unless Dir.exists?(user_config_dir)
      user_files =
        Hash[keys_dir.children
               .select { |k| k.to_s[Regexp.new("#{operator}")] }
               .map { |k| [k.basename.extname.sub(/^[.]/, ''), k] }]

      # copy files
      user_files.keys.reject { |k| k == 'csr' }.each do |f|
        file = user_files[f]
        FileUtils.cp(file, user_config_dir.join(file.basename))
      end

      # copy ca root certificate and ta.key
      keys_dir.children.select { |f| f.to_s[/ca.crt|ta.key/] }.each do |file|
        FileUtils.cp(file, user_config_dir.join(file.basename))
      end

      # generate configuration
      config = ConfigTemplate.new(gateway_addr: gateway_addr,
                                  user_cert: user_files['crt'].basename,
                                  user_key: user_files['key'].basename)
      config.save_file(user_config_dir.join("#{operator}.ovpn"))
    end

    def self.run!(argv)
      opts = opt_parser(argv)
      errors = []
      if !opts.key?(:keys_dir) || opts[:keys_dir].nil?
        errors << proc { fail(OptionParser::MissingArgument, 'Directory for keys is missing') }
      end
      if !opts.key?(:username) || (opts[:username].nil? || opts[:username].empty?)
        errors << proc { fail(OptionParser::MissingArgument, 'Username is missing') }
      end
      if !opts.key?(:gateway_addr) || (opts[:gateway_addr].nil? || opts[:gateway_addr].empty?)
        errors << proc { fail(OptionParser::MissingArgument, 'Gateway address is missing') }
      end
      errors.map(&:call) unless errors.empty?
      runner(opts)
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      puts e.message
      exit
    end
  end
end

# Run generator
OpenVPN::Generator.run!(ARGV)
