# frozen_string_literal: true

require "tprop/version"
require "tprop/errors"
require "tprop/test_case"
require "tprop/gen"
require "tprop/registry"
require "tprop/derive"
require "tprop/testing_state"
require "tprop/structural_equality"
require "tprop/database"

# TProp — property-based testing for Ruby, derived from Sorbet T::Struct types.
#
# See docs/ARCHITECTURE.md for the design. The choice-sequence engine
# (TestCase/Gen/TestingState), the derivation layer (Derive),
# StructuralEquality, and the example database are implemented. The
# Registry/TypeRegistry tiers are still stubs that raise NotImplementedError
# (docs/ROADMAP.md).
module TProp
  DEFAULT_MAX_EXAMPLES = 100

  # Default on-disk location for persisted failing examples.
  DEFAULT_CACHE_DIR = ".tprop-cache"

  class << self
    # The database used by framework integrations (e.g. Minitest's
    # assert_property) when the caller doesn't pass one. Defaults to a
    # FileDatabase under DEFAULT_CACHE_DIR; set to nil to disable persistence,
    # or to a MemoryDatabase to keep a test suite hermetic.
    attr_writer :default_database

    def default_database
      return @default_database if defined?(@default_database)

      @default_database = FileDatabase.new(DEFAULT_CACHE_DIR)
    end
    # Framework-agnostic entry point. Runs `block` against generated values,
    # up to `max_examples` times, and on failure shrinks to a minimal
    # counterexample.
    #
    # Two call shapes:
    #   TProp.check(StructClass, overrides:, max_examples:, seed:) { |value| ... }
    #   TProp.check(gen: some_gen,          max_examples:, seed:) { |value| ... }
    #
    # @param struct_class [Class, nil] a T::Struct subclass to derive from
    # @param gen [TProp::Gen, nil] an explicit generator (mutually exclusive with struct_class)
    # @param overrides [Hash] per-prop generator overrides (tier 5)
    # @param max_examples [Integer]
    # @param seed [Integer, nil]
    # @param database [#[], #[]=, #delete, nil] example database (see TProp::Database)
    # @param key [String, nil] stable key for this property; persistence happens
    #   only when both `database` and `key` are given
    # @raise [TProp::PropertyFailure] when the property fails (carrying the shrunk counterexample)
    def check(struct_class = nil, gen: nil, overrides: {}, max_examples: DEFAULT_MAX_EXAMPLES, seed: nil,
              database: nil, key: nil, &block)
      raise ArgumentError, "provide a struct class or gen:, not both" if struct_class && gen
      raise ArgumentError, "a property block is required" unless block

      generator = gen || Derive.for_struct(struct_class, overrides: overrides)
      rng = seed ? Random.new(seed) : Random.new
      persist = !database.nil? && !key.nil?

      state = TestingState.new(gen: generator, property: block, max_examples: max_examples, rng: rng)
      state.replay(database[key]) if persist # stored failing example replays first
      state.run

      # Persist the outcome: save a (possibly re-shrunk) failure, drop a stale
      # entry once the property passes again.
      if persist
        state.failed? ? database[key] = state.result : database.delete(key)
      end

      raise Unsatisfiable, "no valid examples were generated (every case was rejected)" if state.valid_test_cases.zero?
      return unless state.failed?

      raise build_failure(generator, state.result, block)
    end

    # Register a generator for a whole type, applied at every nesting depth
    # inside Derive.for_type (tier 2). E.g. TProp.register_type(Money) { ... }.
    def register_type(type, &block)
      # TODO: delegate to the type-keyed TypeRegistry.
      raise NotImplementedError, "TProp.register_type is not implemented yet"
    end

    # Register a symbol-keyed hint generator (tier 3/4), resolved from
    # `extra: { tprop: :name }` declaration-site metadata.
    def register(name, &block)
      # TODO: delegate to the symbol-keyed Registry.
      raise NotImplementedError, "TProp.register is not implemented yet"
    end

    # Drop user-registered generators without disturbing built-ins. Important
    # for test isolation of TProp itself and of suites that register.
    def reset_registry!
      # TODO: reset the layered registries' user tier.
      raise NotImplementedError, "TProp.reset_registry! is not implemented yet"
    end

    private

    # Replay the shrunk choice sequence once more to recover the concrete
    # counterexample value and the error the property raised, then package them
    # into a PropertyFailure.
    def build_failure(generator, choices, property)
      test_case = TestCase.for_choices(choices)
      counterexample = nil
      cause = nil
      begin
        counterexample = test_case.any(generator)
        property.call(counterexample)
      rescue StopTest, Frozen
        # control flow only
      rescue Exception => e # rubocop:disable Lint/RescueException
        cause = e
      end

      message = +"Property failed after shrinking to a minimal counterexample:\n"
      message << "  counterexample: #{counterexample.inspect}\n"
      message << "  choice sequence: #{choices.inspect}\n"
      message << "  cause: #{cause.class}: #{cause.message}" if cause

      PropertyFailure.new(message, counterexample: counterexample, choices: choices.dup, cause_error: cause)
    end
  end
end
