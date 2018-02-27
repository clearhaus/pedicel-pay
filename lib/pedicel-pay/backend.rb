require 'pedicel-pay/helper'
require 'pedicel'
require 'openssl'

module PedicelPay
  class Backend
    Error = Class.new(PedicelPay::Error)
    CertificateError = Class.new(PedicelPay::Backend::Error)
    KeyError = Class.new(PedicelPay::Backend::Error)

    attr_accessor \
                :ca_key,           :ca_certificate,
      :intermediate_key, :intermediate_certificate,
              :leaf_key,         :leaf_certificate

    def initialize(          ca_key: nil,           ca_certificate: nil,
                   intermediate_key: nil, intermediate_certificate: nil,
                           leaf_key: nil,         leaf_certificate: nil,
                   valid: PedicelPay.config[:valid])
      @ca_key         = ca_key
      @ca_certificate = ca_certificate

      @intermediate_key         = intermediate_key
      @intermediate_certificate = intermediate_certificate

      @leaf_key         = leaf_key
      @leaf_certificate = leaf_certificate
    end

    def generate_client(valid: PedicelPay.config[:valid])
      client = PedicelPay::Client.new(ca_certificate_pem: ca_certificate.pem)
      client.generate_key

      client.ca_certificate_pem = ca_certificate.to_pem
      client.certificate = sign_csr(client.generate_csr, valid: valid)

      client
    end

    def sign_csr(csr, valid: PedicelPay.config[:valid])
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.not_before = valid.min
      cert.not_after = valid.max
      cert.subject = PedicelPay.config[:subject][:client]
      cert.public_key = csr.public_key
      cert.issuer = intermediate_certificate.issuer
      cert.sign(intermediate_key, OpenSSL::Digest::SHA256.new)

      merchant_id_hex = Helper.bytestring_to_hex(PedicelPay.config[:random].bytes(32))
      oid_ext = OpenSSL::X509::Extension.new(Pedicel.config[:oids][:merchant_identifier_field], merchant_id_hex)

      cert.add_extension(oid_ext)

      cert
    end

    def generate_shared_secret_and_ephemeral_pubkey(recipient:)
      pubkey = case recipient
               when Client
                 OpenSSL::PKey::EC.new(recipient.certificate.public_key).public_key
               when OpenSSL::X509::Certificate
                 OpenSSL::PKey::EC.new(recipient.public_key).public_key
               when OpenSSL::PKey::EC::Point
                 recipient
               else raise ArgumentError, 'invalid recipient'
               end

      ephemeral_seckey = OpenSSL::PKey::EC.new('prime256v1').generate_key

      [ephemeral_seckey.dh_compute_key(pubkey), ephemeral_seckey.public_key]
    end

    def encrypt(token:, recipient:, symmetric_key: nil, shared_secret: nil, ephemeral_pubkey: nil)
      raise ArgumentError, 'invalid token' unless token.is_a?(Token)

      merchant_id = Helper.merchant_id(recipient)
      raise ArgumentError, 'invalid recipient' if merchant_id.nil?

      if symmetric_key && !(shared_secret.nil? && ephemeral_pubkey.nil?)
        raise ArgumentError, 'specify either symmetric_key or both of shared_secret and ephemeral_pubkey'
      elsif shared_secret.nil? ^ ephemeral_pubkey.nil?
        raise ArgumentError, 'shared_secret and ephemeral_pubkey must belong together'
      elsif shared_secret.nil? && ephemeral_pubkey.nil?
        shared_secret, ephemeral_pubkey = generate_shared_secret_and_ephemeral_pubkey(recipient: recipient)
      end

      token.encrypted_data = Helper.encrypt(
        data: token.unencrypted_data.to_json,
        key: Pedicel::EC.symmetric_key(merchant_id: merchant_id, shared_secret: shared_secret)
      )

      token.header.ephemeral_pubkey = ephemeral_pubkey
      token.update_pubkey_hash(recipient: recipient) if recipient

      token
    end

    def sign(token)
      raise ArgumentError, 'token has no encrypted_data' unless token.encrypted_data
      raise ArgumentError, 'token has no ephemeral_pubkey' unless token.header.ephemeral_pubkey

      message = [
        Helper.ec_key_to_pkey_public_key(token.header.ephemeral_pubkey).to_der,
        token.encrypted_data,
        token.header.transaction_id,
        token.header.data_hash,
      ].compact.join

      signature = OpenSSL::PKCS7.sign(
        leaf_certificate,
        leaf_key,
        message,
        [intermediate_certificate, ca_certificate], # Chain.
        OpenSSL::PKCS7::BINARY # Handle 0x00 correctly.
      ).to_der

      token.signature = Base64.strict_encode64(signature)

      token
    end

    def self.generate(valid: PedicelPay.config[:valid])
      ck, cc = generate_ca(valid: valid)

      ik, ic = generate_intermediate(ca_key: ck, ca_certificate: cc, valid: valid)

      lk, lc = generate_leaf(intermediate_key: ik, intermediate_certificate: ic, valid: valid)

      new(ca_key: ck, ca_certificate: cc,
          intermediate_key: ik, intermediate_certificate: ic,
          leaf_key: lk, leaf_certificate: lc,
          valid: valid)
    end


    def self.generate_ca(valid: PedicelPay.config[:valid])
      key = OpenSSL::PKey::EC.new(PedicelPay::EC_CURVE)
      key.generate_key

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2 # https://www.ietf.org/rfc/rfc5280.txt -> Section 4.1, search for "v3(2)".
      cert.serial = 1
      cert.subject = PedicelPay.config[:subject][:ca]
      cert.issuer = cert.subject # Self-signed
      cert.public_key = PedicelPay::Helper.ec_key_to_pkey_public_key(key)
      cert.not_before = valid.min
      cert.not_after = valid.max

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert
      cert.add_extension(ef.create_extension('basicConstraints','CA:TRUE',true))
      cert.add_extension(ef.create_extension('keyUsage','keyCertSign, cRLSign', true))
      cert.add_extension(ef.create_extension('subjectKeyIdentifier','hash',false))
      cert.add_extension(ef.create_extension('authorityKeyIdentifier','keyid:always',false))
      cert.sign(key, OpenSSL::Digest::SHA256.new)

      [key, cert]
    end

    def self.generate_intermediate(ca_key:, ca_certificate:, valid: PedicelPay.config[:valid])
      key = OpenSSL::PKey::EC.new(PedicelPay::EC_CURVE)
      key.generate_key

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2 # https://www.ietf.org/rfc/rfc5280.txt -> Section 4.1, search for "v3(2)".
      cert.serial = 1
      cert.subject = PedicelPay.config[:subject][:intermediate]
      cert.issuer = ca_certificate.subject
      cert.public_key = PedicelPay::Helper.ec_key_to_pkey_public_key(key)
      cert.not_before = valid.min
      cert.not_after = valid.max

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = ca_certificate
      ef.issuer_certificate = ca_certificate
      cert.add_extension(ef.create_extension('keyUsage','keyCertSign, cRLSign', true))
      cert.add_extension(ef.create_extension('subjectKeyIdentifier','hash',false))

      cert.add_extension(OpenSSL::X509::Extension.new(PedicelPay.config[:oid][:intermediate_certificate], ''))

      cert.sign(ca_key, OpenSSL::Digest::SHA256.new)

      [key, cert]
    end

    def self.generate_leaf(intermediate_key:, intermediate_certificate:, valid: PedicelPay.config[:valid])
      key = OpenSSL::PKey::EC.new(PedicelPay::EC_CURVE)
      key.generate_key

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2 # https://www.ietf.org/rfc/rfc5280.txt -> Section 4.1, search for "v3(2)".
      cert.serial = 1
      cert.subject = PedicelPay.config[:subject][:leaf]
      cert.issuer = intermediate_certificate.subject
      cert.public_key = PedicelPay::Helper.ec_key_to_pkey_public_key(key)
      cert.not_before = valid.min
      cert.not_after = valid.max

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = intermediate_certificate
      cert.add_extension(ef.create_extension('keyUsage','digitalSignature', true))
      cert.add_extension(ef.create_extension('subjectKeyIdentifier','hash',false))

      cert.add_extension(OpenSSL::X509::Extension.new(PedicelPay.config[:oid][:leaf_certificate], ''))

      cert.sign(intermediate_key, OpenSSL::Digest::SHA256.new)

      [key, cert]
    end

    def validate
      validate_ca
      validate_intermediate
      validate_leaf

      true
    end

    def validate_ca
      raise KeyError, 'ca private key not valid for ca certificate' unless ca_certificate.check_private_key(ca_key)
      raise CertificateError, 'ca certificate is not self-signed' unless ca_certificate.verify(ca_key)

      true
    end

    def validate_intermediate
      raise KeyError, 'intermediate private key not valid for intermediate certificate' unless intermediate_certificate.check_private_key(intermediate_key)
      raise CertificateError, 'intermediate certificate not signed by ca' unless intermediate_certificate.verify(ca_key)

      true
    end

    def validate_leaf
      raise KeyError, 'leaf private key not valid for leaf certificate' unless leaf_certificate.check_private_key(leaf_key)
      raise CertificateError, 'leaf certificate not signed my intermediate' unless leaf_certificate.verify(intermediate_key)

      true
    end
  end
end
