module OpenVPN
  module Package
    # Create dmg file from given directory
    class DMG
      attr_reader :volume_name, :src_dir, :filename

      def initialize(volume_name, src_dir, filename)
        fail 'DMG image can be create only on OS X platform' unless RUBY_PLATFORM =~ /darwin/
        @volume_name = volume_name
        @src_dir = src_dir
        @filename = filename
      end

      def create
        cmd = %w(hdiutil create)
        cmd << sprintf("-volname \"%s\"", @volume_name)
        cmd << sprintf("-srcfolder \"%s\"", @src_dir)
        cmd << '-ov'
        cmd << '-format UDZO'
        cmd << @filename
        puts `#{cmd.join(' ')}`
      end

      def self.create_bundle(volume_name, src_dir, filename)
        DMG.new(volume_name, src_dir, filename).create
      end
    end

    class ZipArchive
      attr_reader :src_dir, :filename

      def initialize(src_dir, filename, passphrase)
        @src_dir = src_dir
        @filename = filename
        @passphrase = passphrase
      end

      def create
        Zip::Archive.open(@filename.to_s, Zip::CREATE | Zip::TRUNC) do |archive|
          Dir.glob("#{@src_dir}/*").each do |f|
            archive.add_file(f)
          end
          archive.encrypt(@passphrase)
        end
      end

      def self.create_archive(src_dir, filename, passphrase)
        ZipArchive.new(src_dir, filename, passphrase).create
      end
    end
  end
end
