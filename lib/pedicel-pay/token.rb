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
      :encrypted_data

    def initialize(unencrypted_data: nil, encrypted_data: nil, header: nil, signature: nil)
      @unencrypted_data, @encrypted_data, @header, @signature = \
       unencrypted_data,  encrypted_data,   header, signature
    end

    def update_pubkey_hash(recipient:)
      pubkey = case recipient
               when Client                     then recipient.certificate
               when OpenSSL::X509::Certificate then recipient
               else raise ArgumentError, 'invalid recipient'
               end

      header.pubkey_hash = (Digest::SHA256.new << pubkey.to_der).to_s
    end

    def to_json
      {
        'data'      => Base64.strict_encode64(encrypted_data),
        'header'    => header.to_hash,
        'signature' => signature,
        'version'   => 'EC_v1',
      }.to_json
    end

    def sample
      self.unencrypted_data ||= TokenData.new.sample unless self.encrypted_data
      self.header = TokenHeader.new.sample

      self
    end
  end
end
