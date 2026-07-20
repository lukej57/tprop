# frozen_string_literal: true

require "tprop"

module TProp
  # Minitest integration. Include (or it auto-includes on require, see bottom)
  # into your test class to get `assert_property` and `for_all`.
  #
  # Two integration niceties (docs/ARCHITECTURE.md, "Public API surface"):
  #   - reuses Minitest's --seed, so `-s 12345` reproduces a property run.
  #   - converts a TProp::PropertyFailure into a Minitest::Assertion, so a
  #     property failure is reported as F (a failure), not E (an error), while
  #     preserving the shrunk counterexample's backtrace.
  module Minitest
    # Derive a generator from a T::Struct (or use an explicit `gen:`) and assert
    # the block holds across generated values, shrinking on failure.
    #
    #   assert_property(User) do |user|
    #     assert_equal user, User.from_hash(user.serialize)
    #   end
    #
    # @param struct_class [Class, nil] a T::Struct subclass to derive from
    # @param gen [TProp::Gen, nil] an explicit generator
    # @param overrides [Hash] per-prop generator overrides
    # @param max_examples [Integer]
    # @param seed [Integer, nil] defaults to Minitest's seed for reproducibility
    def assert_property(struct_class = nil, gen: nil, overrides: {}, max_examples: TProp::DEFAULT_MAX_EXAMPLES, seed: nil, &block)
      seed ||= tprop_minitest_seed
      TProp.check(struct_class, gen: gen, overrides: overrides, max_examples: max_examples, seed: seed, &block)
      # A completed run without a raised PropertyFailure counts as one assertion.
      assert(true)
    rescue TProp::PropertyFailure => e
      # TODO: format e's shrunk counterexample and re-raise as a
      # Minitest::Assertion (F, not E), preserving e.cause_error's backtrace.
      raise NotImplementedError, "assert_property failure reporting is not implemented yet (#{e.message})"
    end

    # Explicit-generator form: assert the block holds across tuples drawn from
    # each generator.
    #
    #   for_all(Gen.integers, Gen.strings) do |n, s|
    #     assert_operator s.length, :>=, 0
    #   end
    def for_all(*gens, max_examples: TProp::DEFAULT_MAX_EXAMPLES, seed: nil, &block)
      # TODO: combine gens into a tuple generator and delegate to TProp.check.
      raise NotImplementedError, "for_all is not implemented yet"
    end

    private

    # Pull Minitest's seed if available, so property runs reproduce with -s.
    def tprop_minitest_seed
      ::Minitest.respond_to?(:seed) ? ::Minitest.seed : nil
    end
  end
end

# Auto-mix into Minitest test classes on require, matching the "mixed into your
# test class" surface documented in docs/ARCHITECTURE.md.
if defined?(::Minitest::Test)
  ::Minitest::Test.include(TProp::Minitest)
end
