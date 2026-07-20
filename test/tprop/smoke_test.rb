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

  # The engine core (TestCase/Gen/TestingState + TProp.check over an explicit
  # gen:) is implemented — see engine_test.rb. The derivation layer is not yet,
  # so pointing check at a struct class still raises. Canary: flip this when
  # Derive lands.
  def test_derive_is_still_a_stub
    assert_raises(NotImplementedError) { TProp.check(Object) {} }
  end
end
