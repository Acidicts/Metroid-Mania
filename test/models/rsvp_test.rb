require "test_helper"

class RsvpTest < ActiveSupport::TestCase
  test "requires name and slack id" do
    rsvp = Rsvp.new

    assert_not rsvp.valid?
    assert_includes rsvp.errors[:name], "can't be blank"
    assert_includes rsvp.errors[:slack_id], "can't be blank"
  end

  test "allows RSVP without a user" do
    rsvp = Rsvp.new(name: "Guest", slack_id: "UGUEST999")

    assert rsvp.valid?
  end
end
