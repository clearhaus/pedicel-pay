require 'openssl'

module PedicelPay
  class Error < StandardError; end
end

require 'pedicel-pay/backend'
require 'pedicel-pay/client'
require 'pedicel-pay/token'

module PedicelPay
  EC_CURVE = 'prime256v1'

  DEFAULTS = {
    oid: {
      intermediate_certificate:  '1.2.840.113635.100.6.2.14',
      leaf_certificate:          '1.2.840.113635.100.6.29',
      merchant_identifier_field: '1.2.840.113635.100.6.32',
    },
    subject: {
      ca:           OpenSSL::X509::Name.parse('/C=DK/O=Pedicel Inc./OU=Pedicel Certification Authority/CN=Pedicel Root CA - G3'),
      intermediate: OpenSSL::X509::Name.parse('/C=DK/O=Pedicel Inc./OU=Pedicel Certification Authority/CN=Pedicel Application Integration CA - G3'),
      leaf:         OpenSSL::X509::Name.parse('/C=DK/O=Pedicel Inc./OU=pOS Systems/CN=ecc-smp-broker-sign_UC4-PROD'),
      csr:          OpenSSL::X509::Name.parse('/CN=merchant-url.tld'),
      client:       OpenSSL::X509::Name.parse('/UID=merchant-url.tld.pedicel-merchant.PedicelMerchant/CN=Merchant ID: merchant-url.tld.pedicel-merchant.PedicelMerchant/OU=1W2X3Y4Z5A/O=PedicelMerchant Inc./C=DK'),
    },
    random: Random.new,
    valid: Time.new(Time.now.year - 1)..Time.new(Time.now.year + 2),
  }.freeze

  def self.config
    @@config ||= DEFAULTS.dup
  end
end

# Monkey-patch to make OpenSSL::X509::Certificate#sign work.
if OpenSSL::PKey::EC.new.respond_to?(:private_key?) && !OpenSSL::PKey::EC.new.respond_to?(:private?)
  class OpenSSL::PKey::EC
    def private?
      private_key?
    end
  end
end
