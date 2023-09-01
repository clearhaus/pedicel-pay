# frozen_string_literal: true

module PedicelPay
  # Assistance/collection functions.
  class Helper
    def initialize(config: PedicelPay.config, pedicel_instance: nil)
      @config = config
      @pedicel = pedicel_instance
    end

    def self.ec_key_to_pkey_public_key(ec_key)
      # OpenSSL::PKey::EC#public_key is not a PKey public key but an EC point.
      # The ASN1 detour below is because OpenSSL < 3 does not have
      # OpenSSL::PKey::EC#public_to_pem. Otherwise, this method could be served
      # directly to OpenSSL::PKey::EC.new. An approach respecting the
      # immutability of a PKey and the potential absence of #public_to_pem
      # is necessary. See https://stackoverflow.com/a/75572569.
      point = ec_key.is_a?(OpenSSL::PKey::PKey) ? ec_key.public_key : ec_key
      asn1 = OpenSSL::ASN1::Sequence(
        [
          OpenSSL::ASN1::Sequence([
            OpenSSL::ASN1::ObjectId('id-ecPublicKey'),
            OpenSSL::ASN1::ObjectId(ec_key.group.curve_name)
          ]),
          OpenSSL::ASN1::BitString(point.to_octet_string(:uncompressed))
        ]
      )

      OpenSSL::PKey::EC.new(asn1.to_der)
    end

    def self.bytestring_to_hex(string)
      string.unpack('H*').first
    end

    def self.hex_to_bytestring(hex)
      [hex].pack('H*')
    end

    def self.merchant_id(x)
      case x
      when Client
        Pedicel::EC.merchant_id(certificate: x.certificate)
      when OpenSSL::X509::Certificate
        Pedicel::EC.merchant_id(certificate: x)
      when /\A[0-9a-fA-F]{64}\z/
        [x].pack('H*')
      when /\A.{32}\z/
        x
      else
        raise ArgumentError, "cannot extract 'merchant_id' from #{x}"
      end
    end

    def self.recipient_certificate(recipient:)
      case recipient
      when Client                     then recipient.certificate
      when OpenSSL::X509::Certificate then recipient
      else raise ArgumentError, 'invalid recipient'
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
