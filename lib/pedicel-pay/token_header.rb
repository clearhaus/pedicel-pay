module PedicelPay
  class TokenHeader
    Error = Class.new(PedicelPay::Error)

    attr_accessor \
      :data_hash,
      :ephemeral_pubkey,
      :pubkey_hash,
      :transaction_id

    def initialize(data_hash: nil, ephemeral_pubkey: nil, pubkey_hash: nil, transaction_id: nil)
      @data_hash, @ephemeral_pubkey, @pubkey_hash, @transaction_id = \
        data_hash, ephemeral_pubkey,  pubkey_hash,  transaction_id
    end

    def to_hash
      calculate_hash unless pubkey_hash

      result = {
        'ephemeralPublicKey' => Base64.strict_encode64(Helper.ec_key_to_pkey_public_key(ephemeral_pubkey).to_der),
        'publicKeyHash'      => pubkey_hash,
        'transactionId'      => Helper.bytestring_to_hex(transaction_id),
      }
      result.merge!('applicationData' => data_hash) if data_hash

      result
    end

    def sample
      self.transaction_id ||= PedicelPay.config[:random].bytes(5)

      self
    end
  end
end

