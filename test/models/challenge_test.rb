require "test_helper"

class ChallengeTest < ActiveSupport::TestCase
  test "valid with minimal attributes" do
    c = Challenge.new(title: "Speed Week", start_at: 1.day.ago, end_at: 1.day.from_now, multiplier: 1.5, reward_notches: 0)
    assert c.valid?
  end

  test "invalid without title" do
    c = Challenge.new(title: nil)
    assert_not c.valid?
    assert_includes c.errors[:title], "can't be blank"
  end

  test "end must follow start" do
    c = Challenge.new(title: "Bad", start_at: Time.current, end_at: 1.day.ago)
    assert_not c.valid?
    assert c.errors[:end_at].any?
  end

  test "current scope filters active challenges" do
    c = Challenge.create!(title: "Active", start_at: 1.day.ago, end_at: 1.day.from_now, active: true, multiplier: 1.0, reward_notches: 0)
    assert_includes Challenge.current, c
  end

  test "bonus_for calculation" do
    c = Challenge.new(multiplier: 1.5)
    assert_equal 5, c.bonus_for(10)
  end

  test "bonus_for returns 0 without multiplier" do
    c = Challenge.new(multiplier: nil)
    assert_equal 0, c.bonus_for(10)
  end

  test "type defaults to multiplier" do
    c = Challenge.new
    assert_equal "multiplier", c.type
  end

  test "validates multiplier greater than 0" do
    c = Challenge.new(multiplier: 0)
    assert_not c.valid?
    assert c.errors[:multiplier].any?
  end

  test "validates reward_notches >= 0" do
    c = Challenge.new(reward_notches: -1)
    assert_not c.valid?
    assert c.errors[:reward_notches].any?
  end

  test "validates type presence" do
    c = Challenge.new(type: nil)
    assert_not c.valid?
    assert_includes c.errors[:type], "can't be blank"
  end

  test "still_valid deactivates expired challenges" do
    c = Challenge.create!(title: "Expired", start_at: 2.days.ago, end_at: 1.day.ago, active: true, multiplier: 1.0, reward_notches: 0)
    c.still_valid
    assert_not c.reload.active?
  end
end
