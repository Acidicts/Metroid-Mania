require "test_helper"

class WeeklyGoalServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  # Use a tiny threshold so tests don't need to fabricate 100 h of devlogs.
  SMALL_THRESHOLD = 3600  # 1 hour

  setup do
    SiteSetting.set("weekly_goal_threshold_seconds", SMALL_THRESHOLD.to_s)
    SiteSetting.set("weekly_goal_last_awarded_at", "")
    # Delete prize orders first (restrict_with_error prevents direct destroy),
    # then destroy the product.
    prize = Product.find_by(name: "prize")
    if prize
      delete_prize_orders(prize)
      prize.destroy
    end
  end

  teardown do
    SiteSetting.set("weekly_goal_threshold_seconds", "")
    SiteSetting.set("weekly_goal_last_awarded_at", "")
    prize = Product.find_by(name: "prize")
    if prize
      delete_prize_orders(prize)
      prize.destroy
    end
  end

  # Every order (even a free prize order) is linked to a charm slot by
  # Order#deduct_notches_after_create, so those references must be cleared
  # before deleting orders directly – the FK on charm_slots.order_id would
  # otherwise block the DELETE.
  def delete_prize_orders(prize = nil)
    prize ||= Product.find_by(name: "prize")
    return unless prize

    orders = Order.where(product: prize)
    CharmSlot.where(order_id: orders).update_all(order_id: nil)
    orders.delete_all
  end

  # Helper: create a qualifying devlog for the given user and date.
  def devlog_for(user, date: Date.new(2026, 2, 17), seconds: SMALL_THRESHOLD + 1)
    Devlog.create!(
      user: user,
      project: projects(:one),
      title: "work",
      content: "stuff",
      log_date: date,
      duration_seconds: seconds
    )
  end

  # Return the most recently inserted prize order regardless of whether it was
  # produced by the after_commit callback or a direct call.
  def latest_prize_order
    prize = WeeklyGoalService.prize_product
    Order.where(product: prize).order(:id).last
  end

  # --------------------------------------------------------------------------
  # Week window
  # --------------------------------------------------------------------------

  test "week_start is always Monday" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      assert_equal 1, WeeklyGoalService.week_start.wday
    end
  end

  test "week_end is always Sunday" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      assert_equal 0, WeeklyGoalService.week_end.wday
    end
  end

  # --------------------------------------------------------------------------
  # No award when goal not met
  # --------------------------------------------------------------------------

  test "returns false when devlog time is below threshold" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      prize = WeeklyGoalService.prize_product
      Devlog.create!(user: users(:one), project: projects(:one), title: "foo",
                     content: "bar", log_date: Date.new(2026, 2, 17),
                     duration_seconds: 60)
      # callback fired but total was below threshold -> no order was created
      assert_nil Order.where(product: prize).last
    end
  end

  test "does not create a prize order when goal not met" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      prize  = WeeklyGoalService.prize_product
      before = Order.where(product: prize).count
      Devlog.create!(user: users(:one), project: projects(:one), title: "x",
                     content: "y", log_date: Date.new(2026, 2, 17),
                     duration_seconds: 60)
      SiteSetting.set("weekly_goal_last_awarded_at", "")
      WeeklyGoalService.check_and_award!
      assert_equal before, Order.where(product: prize).count
    end
  end

  # --------------------------------------------------------------------------
  # Prize order properties
  # (after_commit :check_weekly_goal fires during devlog_for, so the order
  # exists before check_and_award! is called directly.)
  # --------------------------------------------------------------------------

  test "issued order is free (cost = 0)" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      devlog_for(users(:one))
      order = latest_prize_order
      assert_not_nil order, "Expected a prize order to have been created"
      assert_equal 0.0, order.cost.to_f
    end
  end

  test "issued order product is named 'prize'" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      devlog_for(users(:one))
      order = latest_prize_order
      assert_not_nil order
      assert_equal "prize", order.product.name
    end
  end

  test "prize_product normalizes existing records with different casing" do
    # simulate a legacy product that was created with capital P
    legacy = Product.find_or_create_by!(name: "Prize") do |p|
      p.notch_cost = 0
      p.stock      = 0
      p.show       = false
      p.price_currency = 0
    end

    # calling the helper should return the same record and downcase its name
    prod = WeeklyGoalService.prize_product
    assert_equal legacy.id, prod.id
    assert_equal "prize", prod.name

    # there should only be one product record afterwards
    assert_equal 1, Product.where("lower(name) = ?", "prize").count
  end

  test "issued order status is pending so admin can review and ship" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      devlog_for(users(:one))
      order = latest_prize_order
      assert_not_nil order
      assert order.pending?, "Expected order status to be pending, got: #{order.status.inspect}"
    end
  end

  test "issued order has an auto-generated public_id" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      devlog_for(users(:one))
      order = latest_prize_order
      assert_not_nil order
      assert_match(/\A![A-Za-z0-9]{6}\z/, order.public_id)
    end
  end

  test "winner is a user who logged devlogs this week" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      contributor = users(:one)
      devlog_for(contributor)
      order = latest_prize_order
      assert_not_nil order
      assert_equal contributor.id, order.user_id
    end
  end

  test "non-contributors cannot win" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      contributor     = users(:one)
      non_contributor = users(:two)
      # Only contributor has a devlog this week
      devlog_for(contributor)
      order = latest_prize_order
      assert_not_nil order
      assert_not_equal non_contributor.id, order.user_id
    end
  end

  test "exactly one prize order is created per award" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      prize  = WeeklyGoalService.prize_product
      before = Order.where(product: prize).count
      devlog_for(users(:one))
      assert_equal before + 1, Order.where(product: prize).count
    end
  end

  test "prize product has zero notch cost so no notch balance is required" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      devlog_for(users(:one))
      order = latest_prize_order
      assert_not_nil order
      assert_equal 0, order.product.notch_cost
    end
  end

  test "prize product is hidden from the public storefront" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      devlog_for(users(:one))
      order = latest_prize_order
      assert_not_nil order
      assert_equal false, order.product.show
    end
  end

  # --------------------------------------------------------------------------
  # Audit trail
  # --------------------------------------------------------------------------

  test "creates an audit record when prize is awarded" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      assert_difference "Audit.where(action: 'weekly_goal_awarded').count", 1 do
        devlog_for(users(:one))
      end
    end
  end

  test "audit records total_seconds and winner_id" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      contributor = users(:one)
      devlog_for(contributor)
      audit = Audit.where(action: "weekly_goal_awarded").last
      assert_not_nil audit
      assert audit.details["total_seconds"].to_i >= SMALL_THRESHOLD + 1
      assert_equal contributor.id, audit.details["winner_id"]
    end
  end

  # --------------------------------------------------------------------------
  # Idempotency
  # --------------------------------------------------------------------------

  test "does not award more than once in the same Mon-Sun week" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      prize = WeeklyGoalService.prize_product
      devlog_for(users(:one))                       # award fires via callback
      count_after_first = Order.where(product: prize).count

      # Calling check_and_award! again in the same week must be a no-op
      WeeklyGoalService.check_and_award!
      assert_equal count_after_first, Order.where(product: prize).count
    end
  end

  test "records last_awarded_at after a successful award" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      devlog_for(users(:one))
      assert_not_nil WeeklyGoalService.last_awarded_at
    end
  end

  test "awards again in a new (next) week" do
    prize = WeeklyGoalService.prize_product

    # Week 1 – Tuesday 2026-02-17
    travel_to Time.zone.parse("2026-02-17 12:00") do
      devlog_for(users(:one), date: Date.new(2026, 2, 17))
    end
    assert Order.where(product: prize).count >= 1, "Week 1 should produce a prize order"

    # Remove the week-1 pending order so the uniqueness constraint (pending
    # order per user+product) does not block a week-2 award.
    delete_prize_orders(prize)
    SiteSetting.set("weekly_goal_last_awarded_at", "")

    # Week 2 – Tuesday 2026-02-24
    travel_to Time.zone.parse("2026-02-24 12:00") do
      devlog_for(users(:one), date: Date.new(2026, 2, 24))
    end
    assert Order.where(product: prize).count >= 1, "Week 2 should produce a prize order"
  end

  # --------------------------------------------------------------------------
  # Force award tests
  # --------------------------------------------------------------------------

  test "force_award! ignores threshold and previous award" do
    travel_to Time.zone.parse("2026-02-17 12:00") do
      # small devlog not meeting threshold (use minimum allowed duration)
      devlog_for(users(:one), seconds: 60)
      prize = WeeklyGoalService.prize_product
      before = Order.where(product: prize).count

      order = WeeklyGoalService.force_award!
      assert_not_nil order
      assert_equal before + 1, Order.where(product: prize).count

      # once an order exists pending for the user+product, a second force_award!
      # attempt may be blocked by the unique index.  defensively delete the first
      # order to confirm subsequent calls still succeed.
      CharmSlot.where(order_id: order.id).update_all(order_id: nil)
      Order.where(id: order.id).delete_all
      order2 = WeeklyGoalService.force_award!
      assert_not_nil order2
      # since we removed the initial order, the count should now be back to
      # before + 1 (just the new one).
      assert_equal before + 1, Order.where(product: prize).count
    end
  end

  test "force_award! returns false when no eligible user exists" do
    SiteSetting.set("weekly_goal_last_awarded_at", "")
    assert_not WeeklyGoalService.force_award!
  end

  # --------------------------------------------------------------------------
  # Prize product auto-creation
  # --------------------------------------------------------------------------

  test "prize product is auto-created when absent" do
    assert_nil Product.find_by(name: "prize")
    product = WeeklyGoalService.prize_product
    assert_not_nil product
    assert_equal "prize", product.name
    assert_equal 0, product.notch_cost
    assert_equal false, product.show
  end

  test "prize product is reused if it already exists" do
    existing = WeeklyGoalService.prize_product
    same     = WeeklyGoalService.prize_product
    assert_equal existing.id, same.id
  end
end
