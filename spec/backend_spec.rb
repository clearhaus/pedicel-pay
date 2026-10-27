describe 'PedicelPay::Backend' do
  let(:backend) { PedicelPay::Backend.generate }
  let(:client) { backend.generate_client }
  let(:token) { PedicelPay::Token.new.sample }

  it 'builds a certificate chain that validates' do
    expect(backend.validate).to eq(true)
  end

  it 'issues a client certificate for the generated key' do
    expect(client.certificate.check_private_key(client.key)).to eq(true)
    expect(client.certificate.subject.to_der).to eq(PedicelPay.config[:subject][:client].to_der)
  end

  it 'signs a client CSR with the client key' do
    csr = client.generate_csr

    expect(csr.verify(client.key)).to eq(true)
  end

  it 'encrypts and signs a token that pedicel can decrypt' do
    backend.encrypt_and_sign(token, recipient: client)

    config = Pedicel::DEFAULT_CONFIG.merge(trusted_ca_pem: backend.ca_certificate.to_pem)
    decrypted = Pedicel::EC.new(token.to_hash, config: config).decrypt(
      certificate: client.certificate,
      private_key: client.key
    )

    expect(decrypted).to eq(token.unencrypted_data.to_json)
  end
end
