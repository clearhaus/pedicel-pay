lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'pedicel-pay/version'

Gem::Specification.new do |s|
  s.name          = 'pedicel-pay'
  s.version       = PedicelPay::VERSION
  s.authors       = ['Clearhaus A/S']
  s.email         = ['hello@clearhaus.com']

  s.summary       = 'Backend and client part of Apple Pay'
  s.homepage      = 'https://github.com/clearhaus/pedicel-pay'
  s.license       = 'MIT'

  s.files         = `ls`.split.reject {|f| f.match(/^spec\//) }
  s.bindir        = 'exe'
  s.executables   = s.files.grep(/^exe\//) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'bundler', '~> 1.16'
  s.add_development_dependency 'pry'
  s.add_runtime_dependency 'pedicel', '~> 0.0.2'
  s.add_runtime_dependency 'thor'
  s.add_runtime_dependency 'openssl' # for ruby <= 2.3
end
