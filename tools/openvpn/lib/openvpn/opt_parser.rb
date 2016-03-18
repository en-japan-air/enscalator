module OpenVPN
  module OptParser
    def self.parser(app_name = 'openvpn_conf_gen', argv)
      argv << '-h' if argv.empty?
      options = {}
      opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{app_name} [options]"
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
        options[:output_format] = nil
        opts.on('-f', '--format [OUTPUT_FORMAT]', String, 'Output format (dmg, zip)') do |f|
          f.nil? ? options[:output_format] = :zip : options[:output_format] = f.to_sym
        end
        options[:passphrase] = nil
        opts.on('-p', '--pass [PASSPHRASE]', String, 'Passphrase') do |p|
          p.nil? ? options[:passphrase] = nil : options[:passphrase] = p
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
  end
end
