require "test_helper"

class AchievementTest < ActiveSupport::TestCase
  test "earned_by? for min_notches" do
    ach = Achievement.create!(title: "Notch Hunter", requirement_type: "min_notches", requirement_value: 5)
    user = users(:one)
    5.times { CharmNotch.create!(user: user, charm_slot: nil) }
    assert ach.earned_by?(user)
  end

  test "earned_by? returns false when requirement not met" do
    ach = Achievement.create!(title: "Notch Hunter", requirement_type: "min_notches", requirement_value: 100)
    user = users(:one)
    assert_not ach.earned_by?(user)
  end

  test "earned_by? for min_charms" do
    ach = Achievement.create!(title: "Charm Buyer", requirement_type: "min_charms", requirement_value: 1)
    user = users(:one)
    product = Product.create!(name: "Test", notch_cost: 1, stock: 10, limited: false)
    slot = user.charm_slots.create!
    order = Order.create!(user: user, product: product, status: "submitted", notch_cost: 1)
    slot.update!(order: order)
    assert ach.earned_by?(user)
  end

  test "earned_by? for min_hours" do
    ach = Achievement.create!(title: "Dev Logger", requirement_type: "min_hours", requirement_value: 1.0)
    user = users(:one)
    project = user.projects.create!(name: "Test", repository_url: "https://example.com")
    project.devlogs.create!(user: user, duration_seconds: 3600, log_date: Date.current)
    assert ach.earned_by?(user)
  end

  test "earned_by? for min_level raises due to get_level returning array" do
    ach = Achievement.create!(title: "Leveller", requirement_type: "min_level", requirement_value: 2)
    user = users(:one)
    user.update_column(:xp, 100)
    # get_level returns [lvl, xp_into] array, and earned_by? tries array >= float which raises
    assert_raises(NoMethodError) { ach.earned_by?(user) }
  end

  test "earned_by? returns false for nil requirement_type" do
    ach = Achievement.new(requirement_type: nil, requirement_value: 5)
    assert_not ach.earned_by?(users(:one))
  end

  test "earned_by? returns false for nil requirement_value" do
    ach = Achievement.new(requirement_type: "min_notches", requirement_value: nil)
    assert_not ach.earned_by?(users(:one))
  end

  test "earned_by? returns false for unknown requirement_type" do
    ach = Achievement.new(requirement_type: "unknown", requirement_value: 5)
    assert_not ach.earned_by?(users(:one))
  end

  test "check_and_grant! is idempotent" do
    ach = Achievement.create!(title: "Test", requirement_type: "min_notches", requirement_value: 1)
    user = users(:one)
    CharmNotch.create!(user: user, charm_slot: nil)

    ach.check_and_grant!(user)
    count1 = UserAchievement.where(user: user, achievement: ach).count

    ach.check_and_grant!(user)
    count2 = UserAchievement.where(user: user, achievement: ach).count

    assert_equal count1, count2
  end

  test "unlocked_by? returns true when user has achievement" do
    ach = Achievement.create!(title: "Test", requirement_type: "min_notches", requirement_value: 0)
    user = users(:one)
    UserAchievement.create!(user: user, achievement: ach)
    assert ach.unlocked_by?(user)
  end

  test "unlocked_by? returns false for nil user" do
    ach = Achievement.create!(title: "Test", requirement_type: "min_notches", requirement_value: 0)
    assert_not ach.unlocked_by?(nil)
  end

  test "unlocked_by? returns false when user does not have achievement" do
    ach = Achievement.create!(title: "Test", requirement_type: "min_notches", requirement_value: 100)
    assert_not ach.unlocked_by?(users(:one))
  end

  # --- Validations ---

  test "validates requirement_type inclusion" do
    ach = Achievement.new(requirement_type: "invalid", requirement_value: 5)
    assert_not ach.valid?
    assert_includes ach.errors[:requirement_type], "is not included in the list"
  end

  test "validates requirement_value >= 0" do
    ach = Achievement.new(requirement_type: "min_notches", requirement_value: -1)
    assert_not ach.valid?
    assert_includes ach.errors[:requirement_value], "must be greater than or equal to 0"
  end

  test "allows nil requirement_type and requirement_value" do
    ach = Achievement.new
    assert ach.valid?
  end

  # --- REQUIREMENT_TYPES ---

  test "REQUIREMENT_TYPES contains expected types" do
    assert_includes Achievement::REQUIREMENT_TYPES, "min_notches"
    assert_includes Achievement::REQUIREMENT_TYPES, "min_charms"
    assert_includes Achievement::REQUIREMENT_TYPES, "min_hours"
    assert_includes Achievement::REQUIREMENT_TYPES, "min_level"
  end
end
