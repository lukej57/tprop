# frozen_string_literal: true

module TProp
  # Base class for all TProp errors.
  class Error < StandardError; end

  # Raised when a property fails. Carries the shrunk counterexample and the
  # choice sequence that produced it, so failures can be reported (as F, not E,
  # under Minitest) and replayed.
  class PropertyFailure < Error
    # @return [Object] the minimal (shrunk) counterexample value
    attr_reader :counterexample

    # @return [Array<Integer>, nil] the choice sequence that reproduces it
    attr_reader :choices

    # @return [Exception, nil] the original error the property raised, if any
    attr_reader :cause_error

    def initialize(message = nil, counterexample: nil, choices: nil, cause_error: nil)
      @counterexample = counterexample
      @choices = choices
      @cause_error = cause_error
      super(message)
    end
  end
end
