# frozen_string_literal: true

module PedicelPay
  # Assistance/collection functions.
  class Helper
    def initialize(config: PedicelPay.config, pedicel_instance: nil)
      @config = config
      @pedicel = pedicel_instance
    end

    # Factory to generate apple-pay tokens and certificate chains.
    def self.generate_all(pp_config: PedicelPay.config,
                          token_data: {})

      ck, cc = PedicelPay::Backend.generate_ca(config: pp_config)

      ik, ic = PedicelPay::Backend.generate_intermediate(
        ca_key: ck,
        ca_certificate: cc,
        config: pp_config
      )

      lk, lc = PedicelPay::Backend.generate_leaf(
        intermediate_key: ik,
        intermediate_certificate: ic,
        config: pp_config
      )

      backend = PedicelPay::Backend.new(
        ca_key: ck,
        ca_certificate: cc,
        intermediate_key: ik,
        intermediate_certificate: ic,
        leaf_key: lk,
        leaf_certificate: lc
      )

      merchant = backend.generate_client

      shared_secret, ephemeral_public_key =
        backend.generate_shared_secret_and_ephemeral_pubkey(
          recipient: merchant
        )

      merchant_id = Pedicel::EC.merchant_id(certificate: merchant.certificate)
      symmetric_key = Pedicel::EC.symmetric_key(
        merchant_id: merchant_id,
        shared_secret: shared_secret
      )

      data = PedicelPay::TokenData.new(**token_data).sample
      encrypted_data = PedicelPay::Helper.encrypt(
        data: data.to_json,
        key: symmetric_key
      )

      token_header = PedicelPay::TokenHeader.new(
        ephemeral_pubkey: ephemeral_public_key
      ).sample

      token = PedicelPay::Token.new(
        encrypted_data: encrypted_data,
        unencrypted_data: data,
        header: token_header
      )

      token.update_pubkey_hash(
        recipient: merchant
      )

      backend.sign(token, lc, lk) if pp_config[:sign_token]

      [backend, merchant, token, data]
    end

    def self.ec_key_to_pkey_public_key(ec_key)
      # EC#public_key is not a PKey public key, but an EC point.
      pub = OpenSSL::PKey::EC.new(ec_key.group)
      pub.public_key =
        ec_key.is_a?(OpenSSL::PKey::PKey) ? ec_key.public_key : ec_key

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
