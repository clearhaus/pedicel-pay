lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'pedicel-pay/version'

Gem::Specification.new do |s|
  s.name          = 'pedicel-pay'
  s.version       = PedicelPay::VERSION
  s.author        = 'Clearhaus A/S'
  s.email         = 'hello@clearhaus.com'

  s.summary       = 'Backend and client part of Apple Pay'
  s.homepage      = 'https://github.com/clearhaus/pedicel-pay'
  s.license       = 'MIT'

  s.files         = Dir['lib/**/*.rb'] + Dir['exe/*']
  s.bindir        = 'exe'
  s.executables   = s.files.grep(/^exe\//) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'rake', '~> 12.3'

  # s.add_runtime_dependency 'pedicel', '~> 1.1.0'
  s.add_runtime_dependency 'thor', '~> 0.20'
end
