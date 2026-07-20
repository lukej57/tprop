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
  # recursion is delegated to Ruby's built-in container equality rather than
  # hand-rolled.
  module StructuralEquality
    def ==(other)
      other.class.equal?(self.class) && tprop_prop_values == other.tprop_prop_values
    end

    def eql?(other)
      self == other
    end

    def hash
      [self.class, tprop_prop_values].hash
    end

    protected

    # Prop values in declaration order. Protected so == can call it on `other`
    # (permitted because == only does so after confirming same class).
    def tprop_prop_values
      self.class.props.keys.map { |name| public_send(name) }
    end
  end
end
