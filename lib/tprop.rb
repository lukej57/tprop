# frozen_string_literal: true

require "tprop/version"
require "tprop/errors"
require "tprop/test_case"
require "tprop/gen"
require "tprop/registry"
require "tprop/derive"
require "tprop/testing_state"
require "tprop/structural_equality"

# TProp — property-based testing for Ruby, derived from Sorbet T::Struct types.
#
# See docs/ARCHITECTURE.md for the design this module surface tracks. The
# implementation is currently scaffolding; methods raise NotImplementedError
# until the engine is grounded against real sorbet-runtime (docs/ROADMAP.md,
# "v0.1 FIRST TASK").
module TProp
  DEFAULT_MAX_EXAMPLES = 100

  class << self
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
    # @raise [TProp::PropertyFailure] when the property fails (carrying the shrunk counterexample)
    def check(struct_class = nil, gen: nil, overrides: {}, max_examples: DEFAULT_MAX_EXAMPLES, seed: nil, &block)
      # TODO: build the generator (Derive.for_struct or the given gen), then
      # run it through TestingState. See docs/ARCHITECTURE.md.
      raise NotImplementedError, "TProp.check is not implemented yet"
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
  end
end
