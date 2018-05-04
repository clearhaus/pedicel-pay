# frozen_string_literal: true

module PedicelPay
  # Assistance/collection functions.
  class Helper
    def initialize(config: PedicelPay.config, pedicel_instance: nil)
      @config = config
      @pedicel = pedicel_instance
    end

    def self.ec_key_to_pkey_public_key(ec_key)
      # EC#public_key is not a PKey public key, but an EC point.
      pub = OpenSSL::PKey::EC.new(ec_key.group)
      pub.public_key = ec_key.is_a?(OpenSSL::PKey::PKey) ? ec_key.public_key : ec_key

      pub
    end

    def self.bytestring_to_hex(string)
      string.unpack('H*').first
    end

    def self.merchant_id(x)
      case x
      when Client
        Pedicel::EC.new(config: @pedicel.config)
                   .merchant_id(certificate: x.certificate)
      when OpenSSL::X509::Certificate
        Pedicel::EC.new.merchant_id(certificate: x)
      when /\A[0-9a-fA-F]{64}\z/
        [x].pack('H*')
      when /\A.{32}\z/
        x
      end
    end

    def self.recipient_certificate(recipient)
      case recipient
      when Client
        recipient.certificate
      when OpenSSL::X509::Certificate
        recipient
      end
    end

    def self.encrypt(data:, key:)
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.encrypt
      cipher.key = key
      cipher.iv_len = 16
      cipher.iv = 0.chr * cipher.iv_len
      cipher.auth_data = ''
      cipher.update(data) + cipher.final + cipher.auth_tag
    end
  end
end
