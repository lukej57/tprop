# frozen_string_literal: true

require "tprop"

module TProp
  # Minitest integration. Auto-mixed into Minitest::Test on require, giving
  # `assert_property` and `for_all`.
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
    def assert_property(struct_class = nil, gen: nil, overrides: {}, max_examples: TProp::DEFAULT_MAX_EXAMPLES, seed: nil, &block)
      seed ||= tprop_minitest_seed
      TProp.check(struct_class, gen: gen, overrides: overrides, max_examples: max_examples, seed: seed, &block)
      assert(true) # a completed run without a raised failure counts as an assertion
    rescue TProp::PropertyFailure => e
      raise tprop_failure_assertion(e)
    end

    # Explicit-generator form: assert the block holds across tuples drawn from
    # each generator.
    #
    #   for_all(TProp::Gen.integers(0..9), TProp::Gen.strings) do |n, s|
    #     assert_operator s.length, :>=, 0
    #   end
    def for_all(*gens, max_examples: TProp::DEFAULT_MAX_EXAMPLES, seed: nil, &block)
      seed ||= tprop_minitest_seed
      tuple = TProp::Gen.tuples(*gens)
      TProp.check(gen: tuple, max_examples: max_examples, seed: seed) { |values| block.call(*values) }
      assert(true)
    rescue TProp::PropertyFailure => e
      raise tprop_failure_assertion(e)
    end

    private

    # Convert a PropertyFailure into a Minitest::Assertion (an F), preserving
    # the underlying failure's backtrace when there is one.
    def tprop_failure_assertion(failure)
      assertion = ::Minitest::Assertion.new(failure.message)
      assertion.set_backtrace(failure.cause_error.backtrace) if failure.cause_error&.backtrace
      assertion
    end

    # Pull Minitest's seed if available, so property runs reproduce with -s.
    def tprop_minitest_seed
      ::Minitest.respond_to?(:seed) ? ::Minitest.seed : nil
    end
  end
end

# Auto-mix into Minitest test classes on require.
if defined?(::Minitest::Test)
  ::Minitest::Test.include(TProp::Minitest)
end
