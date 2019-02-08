require 'pedicel-pay/helper'
require 'openssl'
require 'pedicel'

module PedicelPay
  class Client
    attr_accessor :key, :certificate, :ca_certificate_pem

    def initialize(key: nil, certificate: nil, ca_certificate_pem: nil)
      @key = key
      @certificate = certificate
      @ca_certificate_pem = ca_certificate_pem
    end

    def generate_key
      @key = OpenSSL::PKey::EC.new(PedicelPay::EC_CURVE)
      @key.generate_key

      @key
    end

    def generate_csr(subject: PedicelPay.config[:subject][:csr])
      req = OpenSSL::X509::Request.new
      req.version = 0
      req.subject = subject
      req.public_key = PedicelPay::Helper.ec_key_to_pkey_public_key(key)
      req.sign(key, OpenSSL::Digest::SHA256.new)

      req
    end

    def merchant_id
      Pedicel::EC.merchant_id(certificate: certificate)
    end

    def decrypt(token, ca_certificate_pem: @ca_certificate_pem, now: Time.now)
      Pedicel::EC.
        new(token).
        decrypt(private_key: key, certificate: certificate, ca_certificate_pem: ca_certificate_pem, now: now)
    end

    def symmetric_key(token,foo)
      Pedicel::EC.
        new(token).
        symmetric_key(private_key: key, certificate: certificate).
        unpack('H*')
    end
  end
end
