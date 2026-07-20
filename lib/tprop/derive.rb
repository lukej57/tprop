# frozen_string_literal: true

module TProp
  # The derivation layer: turns reified Sorbet types into generators.
  #
  # Derive.for_struct walks StructClass.props and, for each prop, calls
  # Derive.for_type, which does structural recursion over the T::Types::* tree:
  # Simple (Integer, String, Float, …), Union (including T.nilable as
  # T.any(X, NilClass)), TypedArray, TypedHash, T::Enum subclasses, and nested
  # T::Struct (recurse). The composed Gen produces a fully populated instance.
  #
  # NOTE (docs/ROADMAP.md, v0.1 FIRST TASK): this walk was scaffolded against a
  # hand-written T::Types stub. Grounding it against real sorbet-runtime — and
  # confirming the node classes and .props shape — is the first real task
  # before anything here is trustworthy.
  #
  # Known gaps to close: recursion cycle detection for self-/mutually-
  # referential structs, and broader coverage of exotic T::Types nodes.
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
      # TODO: walk struct_class.props; for each prop resolve a Gen (applying
      # the five-tier order), then compose into a struct-building Gen.
      raise NotImplementedError, "Derive.for_struct is not implemented yet"
    end

    # Build a Gen for a single reified type. The tier-2 type-keyed registry is
    # consulted HERE (not in the prop loop) so registrations apply at every
    # nesting depth.
    #
    # @param type [Object] a T::Types::* node (or a raw class)
    # @return [TProp::Gen]
    def for_type(type)
      # TODO: structural recursion over T::Types::Simple / Union / TypedArray /
      # TypedHash / T::Enum / nested T::Struct. See docs/ARCHITECTURE.md.
      raise NotImplementedError, "Derive.for_type is not implemented yet"
    end
  end
end
