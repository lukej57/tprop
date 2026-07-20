# frozen_string_literal: true

require "set"
require "sorbet-runtime"

module TProp
  # The derivation layer: turns reified Sorbet types into generators.
  #
  # Derive.for_struct walks StructClass.props and, for each prop, calls
  # for_type on its `:type_object`, which does structural recursion over the
  # reified type tree (validated against real sorbet-runtime):
  #
  #   T::Types::Simple      -> .raw_type dispatches to a primitive, a nested
  #                            T::Struct (recurse), or a T::Enum (pick a value)
  #   union nodes           -> anything exposing .types: T::Types::Union and
  #                            T::Private::Types::SimplePairUnion (which is what
  #                            T.nilable(X) and T::Boolean actually produce)
  #   T::Types::TypedArray  -> .type (element)
  #   T::Types::TypedHash   -> .keys / .values
  #   T::Types::TypedSet    -> .type
  #   T::Types::FixedArray  -> .inner_types (tuple)
  #
  # The composed Gen produces a fully populated struct instance.
  #
  # Known gap (docs/ROADMAP.md): no recursion cycle detection. A self- or
  # mutually-referential struct raises a clear error rather than looping.
  #
  # See docs/ARCHITECTURE.md, "The derivation layer".
  module Derive
    module_function

    # Build a Gen that produces a fully populated instance of `struct_class`.
    #
    # @param struct_class [Class] a T::Struct subclass
    # @param overrides [Hash{Symbol => TProp::Gen}] per-prop overrides (tier 5)
    # @return [TProp::Gen]
    def for_struct(struct_class, overrides: {})
      build_struct(struct_class, overrides, [])
    end

    # Build a Gen for a single reified type node.
    #
    # @param type [Object] a T::Types::* node
    # @return [TProp::Gen]
    def for_type(type)
      build_type(type, [])
    end

    # --- internals ---------------------------------------------------------

    def build_struct(struct_class, overrides, stack)
      unless struct_class.is_a?(Class) && struct_class < T::Struct
        raise ArgumentError, "#{struct_class.inspect} is not a T::Struct subclass"
      end
      if stack.include?(struct_class)
        raise NotImplementedError,
              "TProp::Derive can't yet derive the recursive struct #{struct_class} " \
              "(cycle: #{(stack + [struct_class]).join(' -> ')}). " \
              "Recursion cycle detection is on the roadmap; supply an override for now."
      end

      inner_stack = stack + [struct_class]
      prop_gens = struct_class.props.map do |name, info|
        gen = overrides[name] || build_type(info.fetch(:type_object), inner_stack)
        [name, gen]
      end

      Gen.new(name: "struct(#{struct_class})") do |tc|
        attrs = {}
        prop_gens.each { |(name, gen)| attrs[name] = tc.any(gen) }
        struct_class.new(**attrs)
      end
    end
    private_class_method :build_struct

    def build_type(type, stack)
      case type
      when T::Types::TypedArray
        Gen.lists(build_type(type.type, stack))
      when T::Types::TypedHash
        pair = Gen.tuples(build_type(type.keys, stack), build_type(type.values, stack))
        Gen.lists(pair).map(&:to_h)
      when T::Types::TypedSet
        Gen.lists(build_type(type.type, stack)).map { |elems| Set.new(elems) }
      when T::Types::FixedArray
        Gen.tuples(*type.inner_types.map { |t| build_type(t, stack) })
      else
        if type.respond_to?(:types) # union: T::Types::Union or SimplePairUnion (nilable/boolean)
          build_union(type, stack)
        elsif type.respond_to?(:raw_type) # T::Types::Simple
          build_simple(type.raw_type, stack)
        else
          raise TProp::Error,
                "TProp::Derive can't derive a generator for #{type.inspect} (#{type.class}). " \
                "Supply an override or register a type generator."
        end
      end
    end
    private_class_method :build_type

    # Order members so nil is first (shrinks toward nil for nilable types),
    # keeping the rest in declaration order.
    def build_union(type, stack)
      nils, others = type.types.partition { |t| t.respond_to?(:raw_type) && t.raw_type == NilClass }
      Gen.one_of(*(nils + others).map { |t| build_type(t, stack) })
    end
    private_class_method :build_union

    def build_simple(raw_type, stack)
      return build_struct(raw_type, {}, stack) if raw_type < T::Struct
      return build_enum(raw_type) if raw_type < T::Enum

      case
      when raw_type == Integer    then default_integer
      when raw_type == Float      then default_float
      when raw_type == String     then Gen.strings
      when raw_type == Symbol     then Gen.strings.map(&:to_sym)
      when raw_type == TrueClass  then Gen.constant(true)
      when raw_type == FalseClass then Gen.constant(false)
      when raw_type == NilClass   then Gen.constant(nil)
      else
        raise TProp::Error,
              "TProp::Derive has no built-in generator for #{raw_type}. " \
              "Supply an override or register a type generator (docs/ROADMAP.md)."
      end
    end
    private_class_method :build_simple

    def build_enum(enum_class)
      Gen.one_of(*enum_class.values.map { |value| Gen.constant(value) })
    end
    private_class_method :build_enum

    # A general-purpose integer generator, small-biased (most values land in a
    # tight range) but reaching wider, and shrinking toward 0. Widen it per-prop
    # with an override when a field's real domain is larger.
    DEFAULT_INTEGER_RANGES = [16, 256, 4096].freeze

    def default_integer
      Gen.one_of(*DEFAULT_INTEGER_RANGES.map { |bound| Gen.integers(-bound..bound) })
    end
    private_class_method :default_integer

    # Naive float generation (whole part + hundredths), shrinking toward 0.0.
    # Better float generation/shrinking is on the roadmap.
    def default_float
      Gen.tuples(default_integer, Gen.integers(0..99)).map { |(whole, hundredths)| whole + (hundredths / 100.0) }
    end
    private_class_method :default_float
  end
end
