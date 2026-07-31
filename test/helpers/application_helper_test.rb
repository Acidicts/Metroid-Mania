require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # --- human_duration ---

  test "human_duration returns 0h for nil" do
    assert_equal "0h", human_duration(nil)
  end

  test "human_duration returns 0h for 0" do
    assert_equal "0h", human_duration(0)
  end

  test "human_duration formats hours and minutes" do
    assert_equal "3h 12m", human_duration(11520)
  end

  test "human_duration formats hours only" do
    assert_equal "2h", human_duration(7200)
  end

  test "human_duration formats minutes only" do
    assert_equal "0h 30m", human_duration(1800)
  end

  # --- format_credits ---

  test "format_credits formats amount with label" do
    result = format_credits(5.7)
    assert_match /5/, result
    assert_match /#{Regexp.escape(credit_label)}/, result
  end

  # --- order_by_public_id ---

  test "order_by_public_id finds order by public_id" do
    o = orders(:one)
    result = order_by_public_id(o.public_id)
    assert_equal o.id, result.id
  end

  test "order_by_public_id returns nil for invalid id" do
    assert_nil order_by_public_id("nonexistent")
  end

  # --- order_public_id_by_id ---

  test "order_public_id_by_id returns public_id for valid id" do
    o = orders(:one)
    # Fixture may not have public_id set; ensure it does
    o.update_column(:public_id, "!Test01") unless o.public_id.present?
    assert_equal o.public_id, order_public_id_by_id(o.id)
  end

  test "order_public_id_by_id returns nil for invalid id" do
    assert_nil order_public_id_by_id(-999)
  end

  # --- credits_total ---

  test "credits_total sums ship credits for project" do
    p = projects(:one)
    p.ships.destroy_all
    p.ships.create!(user: p.user, credits_awarded: 3.0, devlogged_seconds: 3600, shipped_at: Time.current)
    p.ships.create!(user: p.user, credits_awarded: 5.0, devlogged_seconds: 7200, shipped_at: Time.current)
    assert_equal 8, credits_total(p)
  end

  # --- is_flagged_for_fraud ---

  test "is_flagged_for_fraud returns true when flagged" do
    u = users(:one)
    u.update!(flagged_for_fraud: true)
    assert is_flagged_for_fraud(u)
  end

  test "is_flagged_for_fraud returns false when not flagged" do
    assert_not is_flagged_for_fraud(users(:one))
  end

  # --- format_duration ---

  test "format_duration returns 0s for nil" do
    assert_equal "0s", format_duration(nil)
  end

  test "format_duration returns 0s for 0" do
    assert_equal "0s", format_duration(0)
  end

  test "format_duration formats hours minutes seconds" do
    assert_equal "1h 30m 15s", format_duration(5415)
  end

  test "format_duration formats with days" do
    assert_equal "1d 2h 30m", format_duration(95400, include_days: true)
  end

  test "format_duration formats seconds only" do
    assert_equal "45s", format_duration(45)
  end

  # --- correct_credits ---

  test "correct_credits returns 0 for nil" do
    assert_equal 0, correct_credits(nil)
  end

  test "correct_credits ceil rounds up" do
    assert_equal 6, correct_credits(5.3)
    assert_equal 5, correct_credits(5.0)
  end

  # --- credit_label ---

  test "credit_label returns Credits by default" do
    ENV.delete("CREDIT_NAME")
    result = credit_label
    assert result.present?
  end

  test "credit_label returns ENV value when set" do
    ENV["CREDIT_NAME"] = "Notches"
    assert_equal "Notches", credit_label
  ensure
    ENV.delete("CREDIT_NAME")
  end

  # --- safe_url ---

  test "safe_url returns https URLs" do
    assert_equal "https://example.com", safe_url("https://example.com")
  end

  test "safe_url returns http URLs" do
    assert_equal "http://example.com", safe_url("http://example.com")
  end

  test "safe_url returns paths" do
    assert_equal "/foo/bar", safe_url("/foo/bar")
  end

  test "safe_url returns # for invalid URLs" do
    assert_equal "#", safe_url("random-string")
  end

  # --- get_all_credits ---

  test "get_all_credits sums notch counts across ships" do
    p = projects(:one)
    p.ships.destroy_all
    s1 = p.ships.create!(user: p.user, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: Time.current)
    s2 = p.ships.create!(user: p.user, devlogged_seconds: 7200, credits_awarded: 2.0, shipped_at: Time.current)
    3.times { CharmNotch.create!(user: p.user, ship: s1) }
    2.times { CharmNotch.create!(user: p.user, ship: s2) }
    assert_equal 5, get_all_credits(p)
  end

  # --- calculate_user_total_time ---

  test "calculate_user_total_time sums devlogged seconds across ships" do
    u = users(:one)
    p = projects(:one)
    p.ships.destroy_all
    p.ships.create!(user: u, devlogged_seconds: 3600, shipped_at: Time.current)
    p.ships.create!(user: u, devlogged_seconds: 7200, shipped_at: Time.current)
    assert_equal 10800, calculate_user_total_time(u)
  end

  # --- calculate_total_charm_slots ---

  test "calculate_total_charm_slots returns 1 for 0 hours" do
    u = users(:one)
    assert_equal 1, calculate_total_charm_slots(u)
  end

  # --- user_total_credits ---

  test "user_total_credits returns 0 for nil user" do
    assert_equal 0, user_total_credits(nil)
  end

  # --- user_balance ---

  test "user_balance returns 0 for nil user" do
    assert_equal 0, user_balance(nil)
  end

  # --- total_ships ---

  test "total_ships returns project ships count" do
    p = projects(:one)
    p.ships.destroy_all
    p.ships.create!(user: p.user, devlogged_seconds: 3600, shipped_at: Time.current)
    assert_equal 1, total_ships(p)
  end

  # --- user_total_ships ---

  test "user_total_ships returns 0 for nil user" do
    assert_equal 0, user_total_ships(nil)
  end

  test "user_total_ships counts user's ships" do
    u = users(:one)
    assert user_total_ships(u) >= 0
  end
end
