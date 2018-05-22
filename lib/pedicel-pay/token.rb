require 'pedicel-pay/token_data'
require 'pedicel-pay/token_header'
require 'digest'

module PedicelPay
  class Token
    Error = Class.new(PedicelPay::Error)

    attr_accessor \
      :header,
      :signature,
      :unencrypted_data,
      :encrypted_data,
      :version

    def initialize(unencrypted_data: nil, encrypted_data: nil, header: nil, signature: nil, version: 'EC_v1')
      @unencrypted_data = unencrypted_data || TokenData.new
      @encrypted_data   = encrypted_data
      @header           = header || TokenHeader.new
      @signature        = signature
      @version          = version
    end

    def update_pubkey_hash(recipient:)
      pubkey = Helper.recipient_certificate(recipient: recipient)

      header.pubkey_hash = Digest::SHA256.base64digest(pubkey.to_der)
    end

    def to_json
      to_hash.to_json
    end

    def to_hash
      raise Error, 'no encrypted data' unless encrypted_data

      {
        'data'      => Base64.strict_encode64(encrypted_data),
        'header'    => header.to_hash,
        'signature' => signature,
        'version'   => version,
      }
    end

    def sample
      sample_data
      sample_header

      self
    end

    def sample_data
      return if encrypted_data

      if unencrypted_data
        unencrypted_data.sample
      else
        self.unencrypted_data = TokenData.new.sample
      end

      self
    end

    def sample_header
      if header
        header.sample
      else
        self.header = TokenHeader.new.sample
      end

      self
    end
  end
end
