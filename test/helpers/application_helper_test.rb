require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  test "user_total_credits sums credits across user's ships" do
    user = User.create!(provider: 'test', uid: SecureRandom.hex(8), email: 'u1@example.com')
    project = Project.create!(user: user, name: 'P1', repository_url: 'https://example.com/repo')

    project.ships.create!(user: user, shipped_at: Time.current, credits_awarded: 5.5)
    project.ships.create!(user: user, shipped_at: Time.current, credits_awarded: 4.25)

    assert_in_delta 9.75, user_total_credits(user), 0.001
  end

  test "user_total_credits returns 0 for nil or users without ships" do
    user = User.create!(provider: 'test', uid: SecureRandom.hex(8), email: 'u2@example.com')
    assert_equal 0, user_total_credits(user)
    assert_equal 0, user_total_credits(nil)
  end
end
