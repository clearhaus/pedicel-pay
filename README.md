# PedicelPay

A tool to handle the server and client side of Apple Pay. It consist of both a
CLI part and a Ruby library e.g. for testing purposes.

## Usage (CLI)

### Setup a backend and a client

1. Generate a backend (Apple side of Apple Pay):

    $ pedicel-pay generate-backend

   Creates these files:
   * `ca.key`
   * `ca-certificate.pem`
   * `intermediate.key`
   * `intermediate-certificate.pem`
   * `leaf.key`
   * `leaf-certificate.pem`

2. Generate a client (merchant side of Apple Pay):

    $ pedicel-pay generate-client

   Creates `client.key` and `client-certificate.pem`.


### Create tokens

    $ pedicel-pay generate-token \
        --pan=4111111111111111 \
        --expiry=$(date -d 'next year' +%y%m%d) \
        --amount=1234 \
        --currency=978

Specify some values, sample remaining:

    $ pedicel-pay generate-token \
        --pan=4111111111111111 \
        --sample

### Decrypt tokens

    $ echo $TOKEN | pedicel-pay decrypt-token


## Usage (Ruby)

### Setup a backend and a client

```ruby
backend = PedicelPay::Backend.generate
client = backend.generate_client
```

### Create tokens

Sample data

```ruby
token = PedicelPay::Token.new.sample
backend.encrypt(token: token, recipient: client)
backend.sign(token)
puts token.to_json
```

or decide:

```ruby
token = PedicelPay::Token.new

token.unencrypted_data.pan = '4111111111111111'
token.unencrypted_data.currency = '987' # EUR
token.unencrypted_data.amount = 1234 # 12.34 EUR
token.sample # Sample remaining.

backend.encrypt(token: token, recipient: client)
backend.sign(token)
puts token.to_json
```

The JSON formatted Payment Token; refer to
https://developer.apple.com/library/content/documentation/PassKit/Reference/PaymentTokenJSON/PaymentTokenJSON.html


### Decrypt tokens

Using the `client` (if it knows the CA cert):

```ruby
client.decrypt(JSON.parse(token.to_json))
```

To decrypt the token data by hand, use these values:
* The client's secret key `client.key`.
* The merchant ID `client.merchant_id` or client's certificate (containing the
  merchant ID) `client.certificate`.
* Use `backend.ca_certificate` as Apple Root CA G3 certificate.
