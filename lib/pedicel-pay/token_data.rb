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

    CURRENCIES = %w[
      008 012 032 036 044 048 050 051 052 060 064 068 072 084 090 096 104 108
      116 124 132 136 144 152 156 170 174 188 191 192 203 208 214 222 230 232
      238 242 262 270 292 320 324 328 332 340 344 348 352 356 360 364 368 376
      388 392 398 400 404 408 410 414 417 418 422 426 430 434 446 454 458 462
      480 484 496 498 504 512 516 524 532 533 548 554 558 566 578 586 590 598
      600 604 608 634 643 646 654 682 690 694 702 704 706 710 728 748 752 756
      760 764 776 780 784 788 800 807 818 826 834 840 858 860 882 886 901 929
      930 931 932 933 934 936 937 938 940 941 943 944 946 947 948 949 950 951
      952 953 955 956 957 958 959 960 961 962 963 964 965 967 968 969 970 971
      972 973 975 976 977 978 979 980 981 984 985 986 990 994 997 999
    ].freeze

    def initialize(pan: nil, expiry: nil, currency: nil, amount: nil,
                   name: nil, dm_id: nil, cryptogram: nil, eci: nil)
      @pan        = pan
      @expiry     = expiry
      @currency   = currency
      @amount     = amount
      @name       = name
      @dm_id      = dm_id
      @cryptogram = cryptogram
      @eci        = eci
    end

    def to_hash
      data = { onlinePaymentCryptogram: cryptogram }
      data[:eciIndicator] = eci if eci

      result = {
        applicationPrimaryAccountNumber: pan,
        applicationExpirationDate: expiry,
        currencyCode: currency,
        transactionAmount: amount,
        deviceManufacturerIdentifier: dm_id,
        paymentDataType: '3DSecure',
        paymentData: data
      }

      result[:cardholderName] = name if name

      result
    end

    def to_json
      to_hash.to_json
    end

    def sample(expired: nil, pan_length: nil)
      # PAN
      # Override @pan if pan_length doesn't match.
      if pan.nil? || (pan_length && pan.length != pan_length)
        pan_length ||= [12, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 19, 19, 19].sample

        self.pan = [ [2, 4, 5, 6].sample, *(2..pan_length).map { rand(0..9) } ].join
      end

      # Expiry
      # Override @expiry if it doesn't match `expired`.
      # WARNING: Time calculations ahead!
      # Think very carefully about all the crazy corner cases.
      now = Time.now
      if expiry.nil? || (expired ^ card_expired?(now)) # Cannot use "soon".
        self.expiry = self.class.sample_expiry(expired: expired, now: now, soon: now + 5 * 60)
      end

      # Currency
      self.currency ||= CURRENCIES.sample

      # Amount
      self.amount ||= rand(100..99_999)

      # Name

      # Device Manufacturer Identification
      self.dm_id ||= Helper.bytestring_to_hex(PedicelPay.config[:random].bytes(5))

      # Cryptogram
      self.cryptogram ||= Base64.strict_encode64(PedicelPay.config[:random].bytes(20))

      # ECI
      self.eci ||= %w[05 06 07].sample

      self
    end

    def card_expired?(now)
      Time.parse(expired) <= now
    end

    def self.sample_expiry(expired: nil, now: nil, soon: nil)
      # WARNING: Time calculations ahead!
      # Think very carefully about all the crazy corner cases.

      now  ||= Time.now
      soon ||= now + 5 * 60

      year  = sample_expiry_year(expired: expired, soon: soon)
      month = sample_expiry_month(expired: expired, year: year, now: now, soon: soon)

      require 'date'
      Date.civil(year, month, -1).strftime('%y%m%d')
    end

    def self.sample_expiry_year(expired: nil, soon:)
      # WARNING: Time calculations ahead!
      # Think very carefully about all the crazy corner cases.

      case expired
      when nil   then -5..6
      when true  then -5..0
      when false then 0..6
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
        year < now.year ? 1..12 : 1..(now.month - 1)
      when false
        raise DateError, 'cannot expire in a soon future year' if expired && year > soon.year

        year == soon.year ? 1..soon.month : 1..12
      end
        .to_a.sample
    end
  end
end
