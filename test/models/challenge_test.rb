require "test_helper"

class ChallengeTest < ActiveSupport::TestCase
  test "valid with minimal attributes" do
    c = Challenge.new(title: "Ship in 48hrs", reward_notches: 5, start_at: 1.day.ago, end_at: 1.day.from_now, active: true)
    assert c.valid?
  end

  test "invalid without title" do
    c = Challenge.new(reward_notches: 1)
    refute c.valid?
    assert_includes c.errors[:title], "can't be blank"
  end

  test "end must follow start" do
    c = Challenge.new(title: "Fail", start_at: Time.now, end_at: 1.hour.ago)
    refute c.valid?
    assert_includes c.errors[:end_at], "must be after the start time"
  end

  test "current scope only returns active challenges in window" do
    past = Challenge.create!(title: "Past", reward_notches: 0, start_at: 2.days.ago, end_at: 1.day.ago, active: true)
    current = Challenge.create!(title: "Now", reward_notches: 1, start_at: 1.hour.ago, end_at: 1.hour.from_now, active: true)
    inactive = Challenge.create!(title: "Inactive", reward_notches: 1, start_at: 1.hour.ago, end_at: 1.hour.from_now, active: false)

    assert_includes Challenge.current, current
    assert_not_includes Challenge.current, past
    assert_not_includes Challenge.current, inactive
  end

  test "bonus_for calculates correctly" do
    c = Challenge.create!(title: "Mult", reward_notches: 0, multiplier: 1.5)
    assert_equal 5, c.bonus_for(10)
    assert_equal 0, c.bonus_for(0)
  end

  test "type defaults to multiplier and can be set" do
    c = Challenge.create!(title: "T", reward_notches: 0)
    assert_equal "multiplier", c.reload.type

    d = Challenge.create!(title: "Other", reward_notches: 0, type: "something_else")
    assert_equal "something_else", d.type
  end
end
