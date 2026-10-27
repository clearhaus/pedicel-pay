describe 'PedicelPay::Helper' do
  it 'builds an EC public key for the same point' do
    key = OpenSSL::PKey::EC.generate(PedicelPay::EC_CURVE)
    public_key = PedicelPay::Helper.ec_key_to_pkey_public_key(key)

    expect(public_key).to be_a(OpenSSL::PKey::EC)
    expect(public_key.public_key.to_octet_string(:uncompressed)).to eq(
      key.public_key.to_octet_string(:uncompressed)
    )
  end
end
