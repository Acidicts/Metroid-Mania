require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "shipped? returns false when attribute missing (defensive_behavior)" do
    project = Project.new
    # Simulate missing column / attribute by overriding has_attribute? on the instance
    def project.has_attribute?(attr)
      false
    end

    assert_not project.shipped?
  end

  test "shipped? reflects DB value when column exists" do
    project = projects(:one)

    project.update!(shipped: true)
    assert project.shipped?, "Expected shipped? to return true after setting shipped: true"

    project.update!(shipped: false)
    assert_not project.shipped?, "Expected shipped? to return false after setting shipped: false"
  end

  test "hackatime ids must be unique across projects" do
    p1 = projects(:one)
    p2 = projects(:two)

    p1.update!(hackatime_ids: ['Alpha Project'])
    p2.hackatime_ids = ['Alpha Project']
    assert_not p2.valid?
    assert_match /already linked/, p2.errors[:hackatime_ids].join(', ')
  end

  test "minutes_needed_for_ship_request returns remaining minutes to reach 15" do
    p = projects(:one)
    p.devlogs.destroy_all

    assert_equal 15, p.minutes_needed_for_ship_request

    p.devlogs.create!(title: 'Short work', content: 'x', duration_minutes: 5, log_date: Date.today)
    assert_equal 10, p.minutes_needed_for_ship_request

    p.devlogs.create!(title: 'More work', content: 'y', duration_minutes: 10, log_date: Date.today)
    assert_equal 0, p.minutes_needed_for_ship_request
  end

  test "ship_and_award_credits! awards credits and records them on the ship atomically" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)

    # ensure no preexisting ships
    p.ships.destroy_all

    devlogged_seconds = 60 * 120 # 2 hours
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: devlogged_seconds, shipped_at: Time.current)

    assert_in_delta 10.0, ship.credits_awarded, 0.001
    assert_in_delta 10.0, owner.reload.currency.to_f, 0.001
    assert_equal ship, p.ships.order(:created_at).last
  end

  test "award_credits! falls back to total_seconds when seconds argument is 0 or nil" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)

    # project has 12 hours recorded
    p.update!(total_seconds: 12.hours.to_i)
    assert_equal 12.hours.to_i, p.total_seconds, "fixture/update sanity: total_seconds should be 12h"

    # explicit zero should fall back to total_seconds
    amount_zero = p.award_credits!(10, seconds: 0)
    Rails.logger.debug("TEST: amount_zero=#{amount_zero.inspect} owner_currency_after_first=#{p.user.reload.currency.inspect}") if defined?(Rails)
    assert_in_delta 120.0, amount_zero.to_f, 0.001, "award_credits! returned unexpected amount (checks total_seconds usage)"

    # explicit nil should also use total_seconds
    amount_nil = p.award_credits!(10, seconds: nil)
    Rails.logger.debug("TEST: amount_nil=#{amount_nil.inspect} owner_currency_after_second=#{p.user.reload.currency.inspect}") if defined?(Rails)
    assert_in_delta 120.0, amount_nil.to_f, 0.001

    # after two awards the owner should have 240 total
    assert_in_delta 240.0, owner.reload.currency.to_f, 0.001

    # end-to-end via ship_and_award_credits! when devlogged_seconds is 0
    previous = owner.reload.currency.to_f
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 10, devlogged_seconds: 0, shipped_at: Time.current)
    assert_in_delta 120.0, ship.credits_awarded.to_f, 0.001
    assert_in_delta previous + ship.credits_awarded.to_f, owner.reload.currency.to_f, 0.001
  end
end
