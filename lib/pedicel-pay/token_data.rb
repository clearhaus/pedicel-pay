require 'json'

module PedicelPay
  class TokenData
    Error = Class.new(PedicelPay::Error)
    DateError = Class.new(Error)

    attr_accessor \
      :pan,
      :expiry,
      :currency,
      :amount,
      :name,
      :dm_id,
      :cryptogram,
      :eci

    def initialize(pan: nil, expiry: nil, currency: nil, amount: nil, name: nil, dm_id: nil, cryptogram: nil, eci: nil)
      @pan, @expiry, @currency, @amount, @name, @dm_id, @cryptogram, @eci = \
        pan, expiry,  currency,  amount,  name,  dm_id,  cryptogram,  eci
    end

    def to_json
      data = { 'onlinePaymentCryptogram' => cryptogram }
      data.merge!('eciIndicator' => eci) if eci

      result = {
        'applicationPrimaryAccountNumber' => pan,
        'applicationExpirationDate'       => expiry,
        'currencyCode'                    => currency,
        'transactionAmount'               => amount,
        'deviceManufacturerIdentifier'    => dm_id,
        'paymentDataType'                 => '3DSecure',
        'paymentData'                     => data,
      }
      result.merge!('cardholderName' => name) if name

      result.to_json
    end

    def sample(expired: nil, pan_length: nil)
      # PAN
      # Override @pan if pan_length doesn't match.
      if pan.nil? || (pan_length && pan.length != pan_length)
        pan_length ||= [12, 16,16,16,16,16,16,16,16,16,16, 19,19,19].sample
        self.pan = [[2,4,5,6].sample, *(2..pan_length).map{rand(0..9)}].join.to_i
      end

      # Expiry
      # Override @expiry if it doesn't match `expired`.
      # WARNING: Time calculations ahead!
      # Think very carefully about all the crazy corner cases.
      now = Time.now
      if expiry.nil? || (expired ^ card_expired?(now)) # Cannot use "soon".
        self.expiry = self.class.sample_expiry(expired: expired, now: now, soon: now + 5*60)
      end

      # Currency

      # Amount
      self.amount ||= rand(100..99999)

      # Name

      # Device Manufacturer Identification
      self.dm_id = Helper.bytestring_to_hex(PedicelPay.config[:random].bytes(5))

      # Cryptogram
      self.cryptogram = Base64.strict_encode64(PedicelPay.config[:random].bytes(10))

      # ECI
      self.eci = eci || ['05', '06', '07'].sample

      self
    end

    def card_expired?(now)
      Time.parse(expired) <= now
    end

    def self.sample_expiry(expired: nil, now: nil, soon: nil)
      # WARNING: Time calculations ahead!
      # Think very carefully about all the crazy corner cases.

      now  ||= Time.now
      soon ||= now + 5*60

      year  = self.sample_expiry_year(expired: expired, soon: soon)
      month = self.sample_expiry_month(expired: expired, year: year, now: now, soon: soon)

      require 'date'
      Date.civil(year, month, -1).strftime('%y%m%d')
    end

    def self.sample_expiry_year(expired: nil, soon:)
      # WARNING: Time calculations ahead!
      # Think very carefully about all the crazy corner cases.

      case expired
      when nil   then -5..6
      when true  then -5..0
      when false then  0..6
      end
        .map { |i| soon.year + i }
        .to_a.sample
    end

    def self.sample_expiry_month(expired: nil, year:, now:, soon:)
      # WARNING: Time calculations ahead!
      # Think very carefully about all the crazy corner cases.

      case expired
      when nil
        1..12
      when true
        year < now.year ? 1..12 : 1..(now.month-1)
      when false
        raise DateError, 'cannot expire in a soon future year' if expired && year > soon.year
        year == soon.year ? 1..soon.month : 1..12
      end
        .to_a.sample
    end
  end
end

