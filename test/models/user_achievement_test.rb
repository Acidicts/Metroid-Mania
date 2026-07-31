require "test_helper"

class UserAchievementTest < ActiveSupport::TestCase
  test "valid with user and achievement" do
    ach = Achievement.create!(title: "Test", requirement_type: "min_notches", requirement_value: 0)
    ua = UserAchievement.new(user: users(:one), achievement: ach)
    assert ua.valid?
  end

  test "validates user_id uniqueness scoped to achievement" do
    ach = Achievement.create!(title: "Test", requirement_type: "min_notches", requirement_value: 0)
    UserAchievement.create!(user: users(:one), achievement: ach)
    dup = UserAchievement.new(user: users(:one), achievement: ach)
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "already has this achievement"
  end

  test "allows same user with different achievements" do
    ach1 = Achievement.create!(title: "Ach1", requirement_type: "min_notches", requirement_value: 0)
    ach2 = Achievement.create!(title: "Ach2", requirement_type: "min_notches", requirement_value: 0)
    UserAchievement.create!(user: users(:one), achievement: ach1)
    ua2 = UserAchievement.new(user: users(:one), achievement: ach2)
    assert ua2.valid?
  end
end
