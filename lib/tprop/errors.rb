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

  # Raised when a test has no valid examples (every case was rejected/overran).
  class Unsatisfiable < Error; end

  # --- Control-flow signals (not user-facing errors) ---------------------
  #
  # These deliberately subclass Exception, NOT StandardError, so that a bare
  # `rescue => e` in user property code cannot swallow them — only the engine's
  # explicit handlers catch them.

  # Raised by TestCase#mark_status to abort the current run early.
  class StopTest < Exception; end # rubocop:disable Lint/InheritException

  # Raised when choices are made on a test case that has already completed.
  class Frozen < Exception; end # rubocop:disable Lint/InheritException
end
