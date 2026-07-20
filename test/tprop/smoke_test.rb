# frozen_string_literal: true

require "test_helper"

# Non-skipped tests that prove the scaffolding loads and the public surface is
# wired up. These stay green even before the engine is implemented.
class SmokeTest < Minitest::Test
  def test_has_a_version
    assert_match(/\A\d+\.\d+\.\d+/, TProp::VERSION)
  end

  def test_public_surface_exists
    assert_respond_to TProp, :check
    assert_respond_to TProp, :register_type
    assert_kind_of Module, TProp::Derive
    assert defined?(TProp::Gen)
    assert defined?(TProp::TestCase)
    assert defined?(TProp::TestingState)
    assert defined?(TProp::StructuralEquality)
  end

  def test_minitest_integration_is_mixed_in
    assert_respond_to self, :assert_property
    assert_respond_to self, :for_all
  end

  # Derive is implemented (see derive_test.rb). Pointing it at a non-struct is
  # a clear argument error, not a mystery.
  def test_derive_rejects_non_structs
    assert_raises(ArgumentError) { TProp.check(Object) {} }
  end
end
