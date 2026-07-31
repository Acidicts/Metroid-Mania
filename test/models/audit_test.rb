require "test_helper"

class AuditTest < ActiveSupport::TestCase
  test "valid with action" do
    a = Audit.new(action: "ship_approved", user: users(:one))
    assert a.valid?
  end

  test "validates action presence" do
    a = Audit.new(action: nil)
    assert_not a.valid?
    assert_includes a.errors[:action], "can't be blank"
  end

  test "belongs_to user optionally" do
    a = Audit.new(action: "test", user: nil)
    assert a.valid?
  end

  test "belongs_to project optionally" do
    a = Audit.new(action: "test", project: nil)
    assert a.valid?
  end

  test "stores details as JSON" do
    a = Audit.create!(action: "test", user: users(:one), details: { key: "value" })
    assert_equal "value", a.reload.details["key"]
  end
end
