require "test_helper"

class SoftDeletableTest < ActiveSupport::TestCase
  test "scope active returns non-deleted records" do
    p = projects(:one)
    p.update!(deleted_at: nil)
    assert_includes Project.active, p
  end

  test "scope active excludes deleted records" do
    p = projects(:one)
    p.update!(deleted_at: Time.current)
    assert_not_includes Project.active, p
  end

  test "deleted? returns true when deleted_at present" do
    p = projects(:one)
    p.update!(deleted_at: Time.current)
    assert p.deleted_at.present?
  end

  test "deleted? returns false when deleted_at nil" do
    p = projects(:one)
    p.update!(deleted_at: nil)
    assert_nil p.deleted_at
  end

  test "discard sets deleted_at" do
    p = projects(:one)
    p.update!(deleted_at: nil)
    p.update!(deleted_at: Time.current)
    assert_not_nil p.reload.deleted_at
  end

  test "undiscard clears deleted_at" do
    p = projects(:one)
    p.update!(deleted_at: Time.current)
    p.update!(deleted_at: nil)
    assert_nil p.reload.deleted_at
  end
end
