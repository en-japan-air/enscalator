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
fragment 1444
mssfix 1444
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
end
