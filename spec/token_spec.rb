describe 'PedicelPay::Token' do
  it 'samples payment data and a transaction id' do
    token = PedicelPay::Token.new.sample

    expect(token.unencrypted_data.pan).not_to be_nil
    expect(token.unencrypted_data.amount).to be_a(Integer)
    expect(token.header.transaction_id.bytesize).to eq(32)
  end

  it 'refuses to serialize a token that has not been encrypted' do
    token = PedicelPay::Token.new.sample

    expect { token.to_hash }.to raise_error(PedicelPay::Token::Error, 'no encrypted data')
  end
end
