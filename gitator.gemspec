# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gitator/version'

Gem::Specification.new do |spec|
  spec.name          = "gitator"
  spec.version       = Gitator::VERSION
  spec.authors       = ["Prateek Agarwal"]
  spec.email         = ["prat0318@gmail.com"]
  spec.description   = %q{Recommends you Users & repos to follow on the basis of your profile.}
  spec.summary       = %q{TODO: Write a gem summary}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency "rake"
end
