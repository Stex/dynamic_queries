# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dynamic_queries/version'

Gem::Specification.new do |spec|
  spec.name          = 'dynamic_queries'
  spec.version       = DynamicQueries::VERSION
  spec.authors       = ["Stefan Exner"]
  spec.email         = ["stex@sterex.de"]
  spec.summary       = %q{Graphical SQL query generator}
  spec.description   = %q{Graphical SQL query generator}
  spec.homepage      = 'http://www.github.com/stex/dynamic_queries'
  spec.license       = "GPLv2"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'json'
  spec.add_development_dependency 'coffee-script'
  spec.add_development_dependency 'therubyracer'

  spec.add_dependency 'rjs_helpers'
  spec.add_dependency 'haml', '< 4'
  spec.add_dependency 'rails', '~> 2.3'
  spec.add_dependency 'fastercsv'
end
