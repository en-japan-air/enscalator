# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'enscalator/version'

Gem::Specification.new do |spec|
  spec.name          = "enscalator"
  spec.version       = Enscalator::VERSION
  spec.authors       = ["Ugo Bataillard"]
  spec.email         = ["ugo.bataillard@en-japan.io"]

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  end

  spec.summary       = %q{Make enjapan apps webscale}
  spec.description   = %q{Make them really webscale}
  spec.homepage      = "https://www.github.com/en-japan/enscalator"
  spec.license       = "None"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "cloudformation-ruby-dsl", "~> 0.4"
  spec.add_runtime_dependency 'trollop', '~> 2.1'
  spec.add_runtime_dependency 'aws-sdk', '~> 2'

end
