require "test_helper"

class AchievementTest < ActiveSupport::TestCase
  test "earned_by? handles min_notches correctly" do
    user = users(:one)
    # start from blank state
    user.charm_notches.destroy_all

    ach = Achievement.create!(title: "Notch starter", requirement_type: "min_notches", requirement_value: 10)
    assert_not ach.earned_by?(user)

    10.times { user.charm_notches.create!(user: user) }
    assert ach.earned_by?(user)
  end

  test "check_and_grant! only grants once" do
    user = users(:one)
    user.achievements.delete_all

    # give the user a notch so the requirement is met
    user.charm_notches.create!(user: user)

    ach = Achievement.create!(title: "Notch 1", requirement_type: "min_notches", requirement_value: 1)
    assert_nil user.achievements.find_by(id: ach.id)

    # sanity checks before granting
    assert_operator user.charm_notches.count, :>=, 1, "user should have at least one notch"
    assert ach.earned_by?(user), "expected earned_by? to return true for user with one notch"

    ach.check_and_grant!(user)
    user.achievements.reload
    assert user.achievements.include?(ach)

    # when called again it should not duplicate
    assert_no_difference "UserAchievement.count" do
      ach.check_and_grant!(user)
    end
  end

  test "unlocked_by? predicate functions correctly" do
    user = users(:one)
    ach = achievements(:one)

    user.achievements.delete_all
    assert_not ach.unlocked_by?(user)
    assert_not ach.unlocked_by?(nil)

    user.achievements << ach
    assert ach.unlocked_by?(user)
  end
end
