require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "user_total_credits sums credits across user's ships" do
    user = User.create!(provider: "test", uid: SecureRandom.hex(8), email: "u1@example.com")
    project = Project.create!(user: user, name: "P1", repository_url: "https://example.com/repo")

    project.ships.create!(user: user, shipped_at: Time.current, credits_awarded: 5.5)
    project.ships.create!(user: user, shipped_at: Time.current, credits_awarded: 4.25)

    # 5.5 + 4.25 = 9.75, ceiled to nearest integer = 10
    assert_equal 10, user_total_credits(user)
  end

  test "user_total_credits returns 0 for nil or users without ships" do
    user = User.create!(provider: "test", uid: SecureRandom.hex(8), email: "u2@example.com")
    assert_equal 0, user_total_credits(user)
    assert_equal 0, user_total_credits(nil)
  end

  test "user_balance computes shipped minus amount_spent" do
    user = User.create!(provider: "test", uid: SecureRandom.hex(8), email: "u3@example.com")
    project = Project.create!(user: user, name: "P1", repository_url: "https://example.com/repo")
    project.ships.create!(user: user, shipped_at: Time.current, credits_awarded: 10.0)
    project.ships.create!(user: user, shipped_at: Time.current, credits_awarded: 5.0)
    user.update!(amount_spent: 3.0)
    assert_in_delta 12.0, user_balance(user), 0.001
  end

  test "user_total_credits ignores ships from deleted projects" do
    user = User.create!(provider: "test", uid: SecureRandom.hex(8), email: "u4@example.com")
    p1 = Project.create!(user: user, name: "Active", repository_url: "https://example.com/repo")
    p2 = Project.create!(user: user, name: "ToDelete", repository_url: "https://example.com/repo2")

    p1.ships.create!(user: user, shipped_at: Time.current, credits_awarded: 7.0)
    p2.ships.create!(user: user, shipped_at: Time.current, credits_awarded: 5.0)

    # Mark p2 deleted and ensure it is excluded
    p2.update!(deleted_at: Time.current, name: "Deleted Project")

    assert_in_delta 7.0, user_total_credits(user), 0.001
  end
end
