# frozen_string_literal: true

module TProp
  # Symbol-keyed registry for hint generators (tiers 3 and 4 of resolution):
  # built-in hints and user hints declared via `extra: { tprop: :name }`.
  #
  # Layered: user entries shadow built-ins, and #reset_user! drops user state
  # without disturbing built-ins.
  #
  # See docs/ARCHITECTURE.md, "Generator resolution: the five tiers".
  class Registry
    def initialize
      @builtin = {}
      @user = {}
    end

    # @param name [Symbol]
    def register(name, &block)
      raise NotImplementedError, "Registry#register is not implemented yet"
    end

    # @param name [Symbol]
    # @return [TProp::Gen, nil]
    def lookup(name)
      raise NotImplementedError, "Registry#lookup is not implemented yet"
    end

    def reset_user!
      @user = {}
    end
  end

  # Type-keyed registry for whole-type registrations (tier 2). Matched by
  # walking a class's ancestors, so a registration for a base type applies to
  # its subclasses. Hooked inside Derive.for_type, so it applies at every
  # nesting depth.
  class TypeRegistry
    def initialize
      @builtin = {}
      @user = {}
    end

    # @param type [Class]
    def register(type, &block)
      raise NotImplementedError, "TypeRegistry#register is not implemented yet"
    end

    # Resolve by walking the class's ancestors, user tier first.
    # @param type [Class]
    # @return [TProp::Gen, nil]
    def lookup(type)
      raise NotImplementedError, "TypeRegistry#lookup is not implemented yet"
    end

    def reset_user!
      @user = {}
    end
  end
end
