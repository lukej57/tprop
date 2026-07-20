# frozen_string_literal: true

module TProp
  # Mixin giving a T::Struct value equality (==, eql?, hash) by walking .props
  # in declaration order.
  #
  # T::Struct lacks structural equality, which does not affect the engine (the
  # choice-sequence machinery never compares struct instances) but does bite
  # the equational properties users write — round-trips, algebraic laws, any
  # f(x) == y.
  #
  # Deliberate decisions (docs/ARCHITECTURE.md, "Companion value-object
  # support"): the comparison helper is protected (so == can call it on other),
  # matching is exact-class (not is_a?, to keep == symmetric), and nested-struct
  # recursion is delegated to Ruby's built-in container equality.
  module StructuralEquality
    def ==(other)
      # TODO: exact-class check, then compare prop values in declaration order.
      raise NotImplementedError, "StructuralEquality#== is not implemented yet"
    end

    def eql?(other)
      self == other
    end

    def hash
      # TODO: hash over prop values in declaration order.
      raise NotImplementedError, "StructuralEquality#hash is not implemented yet"
    end

    protected

    # The comparison helper, protected so == can call it on `other`.
    def tprop_prop_values
      raise NotImplementedError, "StructuralEquality#tprop_prop_values is not implemented yet"
    end
  end
end
