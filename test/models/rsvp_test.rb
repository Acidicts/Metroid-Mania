require "test_helper"

class RsvpTest < ActiveSupport::TestCase
  test "requires name" do
    r = Rsvp.new(name: nil, slack_id: "U123")
    assert_not r.valid?
    assert_includes r.errors[:name], "can't be blank"
  end

  test "requires slack_id" do
    r = Rsvp.new(name: "Alice", slack_id: nil)
    assert_not r.valid?
    assert_includes r.errors[:slack_id], "can't be blank"
  end

  test "allows RSVP without user" do
    r = Rsvp.new(name: "Alice", slack_id: "U123")
    assert r.valid?
  end

  test "belongs_to user optionally" do
    r = Rsvp.new(user: nil, name: "Test", slack_id: "U123")
    assert r.valid?
  end

  test "normalize_fields strips whitespace" do
    r = Rsvp.create!(name: "  Alice  ", slack_id: "  U123  ")
    assert_equal "Alice", r.name
    assert_equal "U123", r.slack_id
  end
end
