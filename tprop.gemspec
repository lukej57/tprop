# frozen_string_literal: true

require_relative "lib/tprop/version"

Gem::Specification.new do |spec|
  spec.name        = "tprop"
  spec.version     = TProp::VERSION
  spec.authors     = ["Luke Jeremy"]
  spec.email       = ["luke.jeremy@tanda.com.au"]

  spec.summary     = "Property-based testing for Ruby, derived from Sorbet T::Struct types."
  spec.description = <<~DESC
    TProp turns the type information you already wrote into generators. A
    T::Struct declaration is a machine-readable schema, so YourStruct.props IS
    the generator, waiting to be interpreted. TProp interprets it, runs your
    property hundreds of times, and shrinks any failure to a minimal
    counterexample for free. Inspired by Hypothesis/minithesis choice-sequence
    generation and shrinking.
  DESC
  spec.homepage = "https://github.com/lukej57/tprop"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = spec.homepage
  spec.metadata["changelog_uri"]     = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "docs/**/*.md",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]

  # The library is fundamentally built on runtime-reified Sorbet types.
  spec.add_dependency "sorbet-runtime", ">= 0.5"
end
