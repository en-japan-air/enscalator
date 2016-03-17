module OpenVPN
  module Runner

    CONFIG_FILENAME = 'fuman-vpc-gateway.ovpn'

    def self.generator(options = {})
      work_dir = Pathname.new(Dir.pwd).join('users/openvpn')
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
      config.save_file(user_config_dir.join(CONFIG_FILENAME))

      # create dmg bundle
      # TODO: use zip
      if options[:output_format] == :dmg
        Package::DMG.create_bundle("OpenVPN Config #{operator}",
                                   user_config_dir.to_s,
                                   work_dir.join("#{operator}.dmg"))
      elsif options[:output_format] == :zip
        Package::ZipArchive.create_archive(user_config_dir.to_s,
                                           work_dir.join("#{operator}.zip"),
                                           options[:passphrase])
      else
        fail "Unsupported format: #{options[:output_format]}"
      end

      # remove directory with intermediate files
      FileUtils.rm_rf(user_config_dir)
    end

    def self.run!(argv)
      opts = OptParser.parser(argv)
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
      if !opts.key?(:output_format) || (opts[:output_format].nil? || opts[:output_format].empty?)
        opts[:output_format] = :zip
      end
      if opts.key?(:passphrase) && (opts.key?(:output_format) && opts[:output_format] == :dmg)
        warn('Passphrase was given, but is not supported for dmg images.')
      end
      if !opts.key?(:passphrase) || (opts[:passphrase].nil? || opts[:passphrase].empty?)
        errors << proc { fail(OptionParser::MissingArgument, 'Gateway address is missing') }
      end
      errors.map(&:call) unless errors.empty?
      generator(opts)
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      puts e.message
      exit
    end
  end
end
