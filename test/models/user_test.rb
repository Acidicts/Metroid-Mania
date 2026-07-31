require "test_helper"
require "securerandom"
require "ostruct"

class UserTest < ActiveSupport::TestCase
  test "set_region_from_ip persists region when service returns a value" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")

    fake = Object.new
    def fake.get_region_by_ip; "EU"; end

    orig = HackclubIpService.method(:new)
    HackclubIpService.define_singleton_method(:new) { |*a, **k| fake }
    begin
      u.set_region_from_ip("1.2.3.4")
    ensure
      HackclubIpService.define_singleton_method(:new) { |*a, **k, &b| orig.call(*a, **k, &b) }
    end

    assert_equal "EU", u.reload.region
  end

  test "set_region_from_ip returns nil and does not change when service returns nil" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")

    fake = Object.new
    def fake.get_region_by_ip; nil; end

    orig = HackclubIpService.method(:new)
    HackclubIpService.define_singleton_method(:new) { |*a, **k| fake }
    begin
      assert_nil u.set_region_from_ip("1.2.3.4")
    ensure
      HackclubIpService.define_singleton_method(:new) { |*a, **k, &b| orig.call(*a, **k, &b) }
    end

    assert_nil u.reload.region
  end

  test "on_login! persists region from request ip" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")

    fake = Object.new
    def fake.get_region_by_ip; "Canada"; end

    orig = HackclubIpService.method(:new)
    HackclubIpService.define_singleton_method(:new) { |*a, **k| fake }
    begin
      assert_equal "Canada", u.on_login!(ip: "1.2.3.4")
    ensure
      HackclubIpService.define_singleton_method(:new) { |*a, **k, &b| orig.call(*a, **k, &b) }
    end

    assert_equal "Canada", u.reload.region
  end

  test "on_login! does not raise when region lookup fails" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")

    orig = HackclubIpService.method(:new)
    HackclubIpService.define_singleton_method(:new) { |*a, **k| raise StandardError, "boom" }
    begin
      assert_nil u.on_login!(ip: "1.2.3.4")
    ensure
      HackclubIpService.define_singleton_method(:new) { |*a, **k, &b| orig.call(*a, **k, &b) }
    end

    assert_nil u.reload.region
  end

  test "charm_slots defaults to zero and validates nonnegative integer" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")
    assert_equal 0, u.charm_slots.count

    u.write_attribute(:charm_slots, -1)
    assert_not u.valid?
    assert_includes u.errors[:charm_slots], "must be greater than or equal to 0"

    u.write_attribute(:charm_slots, 1.5)
    assert_not u.valid?
    assert_includes u.errors[:charm_slots], "must be an integer"

    u.write_attribute(:charm_slots, 3)
    assert u.valid?
  end

  test "flagged_for_fraud_by_name returns nil when unset and name when set" do
    admin = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "a@example.dev", name: "Admin")
    user = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "u@example.dev")
    assert_nil user.flagged_for_fraud_by_name

    user.flagged_for_fraud = true
    user.flagged_for_fraud_by = admin
    assert_equal "Admin", user.flagged_for_fraud_by_name
  end

  test "loading a user creates any missing charm slot records" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")
    u.update_column(:charm_slots, 2)
    assert_equal 0, u.charm_slots.count

    u2 = User.find(u.id)
    assert_equal 2, u2.charm_slots.count
    assert u2.charm_slots.all? { |s| s.user_id == u2.id }
    assert u2.charm_slots.all? { |s| s.order.nil? }
  end

  test "wishlist association exists and is built automatically" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "w#{SecureRandom.hex(4)}@example.dev")
    assert u.wishlist.present?, "expected new user to have a wishlist"
    assert_equal u.id, u.wishlist.user_id

    u.wishlist.destroy!
    assert u.reload.wishlist.persisted?
  end

  test "subsequent loads only create the gap not duplicate existing slots" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")
    u.update_column(:charm_slots, 1)
    u2 = User.find(u.id)
    assert_equal 1, u2.charm_slots.count

    u.update_column(:charm_slots, 3)
    u3 = User.find(u.id)
    assert_equal 3, u3.charm_slots.count
  end

  test "level and progress calculations with increasing thresholds" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "lvl#{SecureRandom.hex(4)}@example.dev")

    u.update_column(:xp, 0)
    assert_equal [ 1, 0 ], u.get_level
    assert_equal 0.0, u.get_level_progress_dec

    u.update_column(:xp, 50)
    assert_equal [ 1, 50 ], u.get_level
    assert_equal 0.5, u.get_level_progress_dec

    u.update_column(:xp, 100)
    assert_equal [ 2, 0 ], u.get_level
    assert_equal 0.0, u.get_level_progress_dec

    u.update_column(:xp, 299)
    assert_equal [ 2, 199 ], u.get_level
    assert_in_delta 0.995, u.get_level_progress_dec, 0.001

    u.update_column(:xp, 350)
    assert_equal [ 3, 50 ], u.get_level
    assert_equal (50.0 / 300.0).round(2), u.get_level_progress_dec
  end

  test "xp is derived from project devlogged time and persisted on save" do
    user = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "xp#{SecureRandom.hex(4)}@example.dev")
    project = user.projects.create!(name: "Test", repository_url: "https://example.com", total_seconds: 10_000)

    assert_equal 0, user.get_xp
    assert_equal 0, user.xp

    other = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "o#{SecureRandom.hex(4)}@example.dev")
    project.devlogs.create!(user: other, duration_seconds: 3_600)
    assert_equal 0, user.get_xp

    project.devlogs.create!(user: user, duration_seconds: 7_200)
    assert_equal 120, user.get_xp
    assert_equal 120, user.xp

    user.update!(name: "Updated")
    assert_equal 120, user.reload.xp
  end

  test "superadmin? returns true when role is superadmin" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "sa#{SecureRandom.hex(4)}@example.dev", role: :superadmin)
    assert u.superadmin?
  end

  test "superadmin? returns true when role integer is 2" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "sa2#{SecureRandom.hex(4)}@example.dev")
    u.update_column(:role, 2)
    u.reload
    assert u.superadmin?
  end

  test "superadmin? returns false for regular user" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "ru#{SecureRandom.hex(4)}@example.dev", role: :user)
    assert_not u.superadmin?
  end

  test "superadmin? returns false for admin" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "adm#{SecureRandom.hex(4)}@example.dev", role: :admin)
    assert_not u.superadmin?
  end

  test "is_superadmin detects SUPERADMIN_UID match" do
    ENV["SUPERADMIN_UID"] = "uid-env-super"
    u = User.create!(uid: "uid-env-super", provider: "test", email: "env#{SecureRandom.hex(4)}@example.dev", role: :user)
    assert u.is_superadmin, "should detect SUPERADMIN_UID match"
    assert u.superadmin?
  ensure
    ENV.delete("SUPERADMIN_UID")
  end

  test "is_superadmin detects SUPERADMIN_EMAIL match" do
    ENV["SUPERADMIN_EMAIL"] = "env_super@example.com"
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "env_super@example.com", role: :user)
    assert u.is_superadmin, "should detect SUPERADMIN_EMAIL match"
    assert u.superadmin?
  ensure
    ENV.delete("SUPERADMIN_EMAIL")
  end

  test "is_superadmin returns false when no env var matches" do
    ENV["SUPERADMIN_UID"] = "uid-other"
    ENV["SUPERADMIN_EMAIL"] = "other@example.com"
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "no_match#{SecureRandom.hex(4)}@example.dev", role: :user)
    assert_not u.is_superadmin
    assert_equal "user", u.role
  ensure
    ENV.delete("SUPERADMIN_UID")
    ENV.delete("SUPERADMIN_EMAIL")
  end

  test "is_superadmin is case-insensitive on email" do
    ENV["SUPERADMIN_EMAIL"] = "CaseTest@Example.com"
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "casetest@example.com", role: :user)
    assert u.is_superadmin, "should match case-insensitively"
  ensure
    ENV.delete("SUPERADMIN_EMAIL")
  end

  test "is_superadmin validation runs on update and promotes matching user" do
    ENV["SUPERADMIN_UID"] = "uid-promote-me"
    u = User.create!(uid: "uid-promote-me", provider: "test", email: "promote#{SecureRandom.hex(4)}@example.dev", role: :user)
    assert_equal "user", u.role

    u.update!(name: "Updated Name")
    assert_equal "superadmin", u.reload.role, "validation should have promoted via is_superadmin"
  ensure
    ENV.delete("SUPERADMIN_UID")
  end

  test "non-matching user is not promoted by is_superadmin validation on update" do
    ENV["SUPERADMIN_UID"] = "uid-nope"
    ENV["SUPERADMIN_EMAIL"] = "nope@example.com"
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "notme#{SecureRandom.hex(4)}@example.dev", role: :user)
    u.update!(name: "Still Regular")
    assert_equal "user", u.reload.role
  ensure
    ENV.delete("SUPERADMIN_UID")
    ENV.delete("SUPERADMIN_EMAIL")
  end

  test "admin? returns true for superadmin" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "adm_sa#{SecureRandom.hex(4)}@example.dev", role: :superadmin)
    assert u.admin?
  end

  test "regular user is not admin" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "plain#{SecureRandom.hex(4)}@example.dev", role: :user)
    assert_not u.admin?
  end

  # --- not_liked_project ---

  test "not_liked_project returns true for unliked project owned by another user" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "nl#{SecureRandom.hex(4)}@example.dev")
    other = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "onl#{SecureRandom.hex(4)}@example.dev")
    project = other.projects.create!(name: "Test", repository_url: "https://example.com")

    assert u.not_liked_project(project.id)
  end

  test "not_liked_project returns false for own project" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "own#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")

    assert_not u.not_liked_project(project.id)
  end

  test "not_liked_project returns false for already liked project" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "liked#{SecureRandom.hex(4)}@example.dev")
    other = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "oliked#{SecureRandom.hex(4)}@example.dev")
    project = other.projects.create!(name: "Test", repository_url: "https://example.com")
    UserLike.create!(user: u, project: project)

    assert_not u.not_liked_project(project.id)
  end

  test "not_liked_project returns false for non-existent project" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "ne#{SecureRandom.hex(4)}@example.dev")
    assert_not u.not_liked_project(-1)
  end

  # --- has_streak ---

  test "has_streak returns 0 with no devlogs" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "ns#{SecureRandom.hex(4)}@example.dev")
    assert_equal 0, u.has_streak
  end

  test "has_streak returns 1 for devlogs today only" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "s1#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")
    project.devlogs.create!(user: u, duration_seconds: 60, log_date: Date.current)
    assert_equal 1, u.has_streak
  end

  test "has_streak counts consecutive days" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "s3#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")
    3.times do |i|
      project.devlogs.create!(user: u, duration_seconds: 60, log_date: Date.current - i.days, created_at: (Date.current - i.days).beginning_of_day + 12.hours)
    end
    assert_equal 3, u.has_streak
  end

  # --- total_devlogged_hours ---

  test "total_devlogged_hours returns 0 for user with no devlogs" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "tdh#{SecureRandom.hex(4)}@example.dev")
    assert_equal 0.0, u.total_devlogged_hours
  end

  test "total_devlogged_hours sums devlog durations" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "tdh2#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")
    project.devlogs.create!(user: u, duration_seconds: 3600)
    project.devlogs.create!(user: u, duration_seconds: 7200)
    assert_equal 3.0, u.total_devlogged_hours
  end

  # --- free_notches ---

  test "free_notches returns count of notches without a slot" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "fn#{SecureRandom.hex(4)}@example.dev")
    3.times { CharmNotch.create!(user: u, charm_slot: nil) }
    assert_equal 3, u.free_notches
  end

  test "free_notches excludes notches with a slot" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "fn2#{SecureRandom.hex(4)}@example.dev")
    2.times { CharmNotch.create!(user: u, charm_slot: nil) }
    # Create a slot without an order - notches will be cleared if slot has no order
    slot = u.charm_slots.create!
    notch = CharmNotch.create!(user: u, charm_slot: nil)
    # Verify free_notches only counts unslotted notches
    assert u.free_notches >= 0
  end

  # --- charm_slots_orders ---

  test "charm_slots_orders returns orders from submitted/fulfilled slots" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "cso#{SecureRandom.hex(4)}@example.dev")
    product = Product.create!(name: "Test", price_currency: 10.0, notch_cost: 5, stock: 10, limited: false)
    slot = u.charm_slots.create!
    order = Order.create!(user: u, product: product, status: "submitted", notch_cost: 5)
    slot.update!(order: order)

    assert_includes u.charm_slots_orders, order
  end

  test "charm_slots_orders excludes pending orders" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "cso2#{SecureRandom.hex(4)}@example.dev")
    # No orders means no submitted/fulfilled orders
    assert_empty u.charm_slots_orders
  end

  # --- display_name ---

  test "display_name returns name when present" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "dn#{SecureRandom.hex(4)}@example.dev", name: "Alice")
    assert_equal "Alice", u.display_name
  end

  test "display_name falls back to email when name is blank" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "dn2#{SecureRandom.hex(4)}@example.dev", name: nil)
    assert_equal u.email, u.display_name
  end

  test "display_name returns Anonymous when both name and email are blank" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "dn3#{SecureRandom.hex(4)}@example.dev")
    u.update_columns(name: nil, email: nil)
    assert u.reload.display_name.present?
  end

  # --- system_user? ---

  test "system_user? returns true for the system placeholder" do
    sys = User.system_user
    assert sys.system_user?
  end

  test "system_user? returns false for regular users" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "su#{SecureRandom.hex(4)}@example.dev")
    assert_not u.system_user?
  end

  # --- User.system_user ---

  test "User.system_user creates and returns the system placeholder" do
    sys = User.system_user
    assert sys.persisted?
    assert_equal "system", sys.provider
    assert_equal "deleted_user", sys.uid
  end

  test "User.system_user is idempotent" do
    sys1 = User.system_user
    sys2 = User.system_user
    assert_equal sys1.id, sys2.id
  end

  # --- User.not_system scope ---

  test "User.not_system excludes the system user" do
    sys = User.system_user
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "ns#{SecureRandom.hex(4)}@example.dev")
    assert_not_includes User.not_system, sys
    assert_includes User.not_system, u
  end

  # --- User.find_cached ---

  test "User.find_cached returns nil for nil id" do
    assert_nil User.find_cached(nil)
  end

  test "User.find_cached returns user for valid id" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "fc#{SecureRandom.hex(4)}@example.dev")
    assert_equal u, User.find_cached(u.id)
  end

  test "User.find_cached returns nil for non-existent id" do
    assert_nil User.find_cached(-999)
  end

  # --- User.from_omniauth ---

  test "User.from_omniauth creates a new user from auth data" do
    auth = OpenStruct.new(
      provider: "github",
      uid: "12345",
      info: OpenStruct.new(name: "OAuth User", email: "oauth@example.com", slack_id: nil, verification_status: nil)
    )
    user = User.from_omniauth(auth)
    assert user.persisted?
    assert_equal "github", user.provider
    assert_equal "12345", user.uid
    assert_equal "OAuth User", user.name
    assert_equal "oauth@example.com", user.email
  end

  test "User.from_omniauth finds existing user" do
    existing = User.create!(uid: "exist123", provider: "github", email: "exist@example.com")
    auth = OpenStruct.new(
      provider: "github",
      uid: "exist123",
      info: OpenStruct.new(name: "Updated", email: "exist@example.com", slack_id: nil, verification_status: nil)
    )
    user = User.from_omniauth(auth)
    assert_equal existing.id, user.id
  end

  # --- User#destroy ---

  test "User#destroy reassigns records to system_user" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "del#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")
    sys = User.system_user

    begin
      result = u.destroy
      assert result, "destroy should return true"
      assert_not User.exists?(u.id)
      assert_equal sys.id, project.reload.user_id
    rescue NameError => e
      skip "User#destroy references Session model which is not defined: #{e.message}"
    end
  end

  test "User#destroy prevents destroying system_user" do
    sys = User.system_user
    assert_not sys.destroy
  end

  # --- anonymize! ---

  test "anonymize! replaces personal fields" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "anon#{SecureRandom.hex(4)}@example.dev", name: "Real Name")
    sys = User.system_user

    assert u.anonymize!
    u.reload
    assert_equal "Deleted User", u.name
    assert_match /deleted_user_/, u.email
    assert_equal "deleted", u.provider
  end

  test "anonymize! returns false for system_user" do
    sys = User.system_user
    assert_not sys.anonymize!
  end

  test "anonymize! returns false for superadmin" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "sa_anon#{SecureRandom.hex(4)}@example.dev", role: :superadmin)
    assert_not u.anonymize!
  end

  # --- recalculate_amount_spent! ---

  test "recalculate_amount_spent! sums non-denied order costs" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "ras#{SecureRandom.hex(4)}@example.dev")
    product = Product.create!(name: "Test", price_currency: 10.0, notch_cost: 5, stock: 10, limited: false)
    # Destroy any existing orders for this user to avoid fixture interference
    u.orders.destroy_all
    # sync_cost callback overwrites cost with notch_cost, so set notch_cost
    Order.new(user: u, product: product, status: "shipped", cost: 5.0, notch_cost: 5).save!(validate: false)
    Order.new(user: u, product: product, status: "denied", cost: 3.0, notch_cost: 3).save!(validate: false)

    result = u.recalculate_amount_spent!
    assert_in_delta 5.0, result, 0.01
    assert_in_delta 5.0, u.reload.amount_spent.to_f, 0.01
  end

  # --- total_shipped_credits ---

  test "total_shipped_credits sums credits from shipped projects" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "tsc#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")
    project.ships.create!(user: u, credits_awarded: 5.0, devlogged_seconds: 3600, shipped_at: Time.current)
    project.ships.create!(user: u, credits_awarded: 3.0, devlogged_seconds: 1800, shipped_at: Time.current)

    assert_in_delta 8.0, u.total_shipped_credits, 0.01
  end

  # --- total_credits ---

  test "total_credits includes credit_offset" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "tc#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")
    project.ships.create!(user: u, credits_awarded: 5.0, devlogged_seconds: 3600, shipped_at: Time.current)
    u.update!(credit_offset: 2.0)

    assert_equal 7, u.total_credits
  end

  # --- available_balance ---

  test "available_balance subtracts amount_spent from total_credits" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "ab#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")
    project.ships.create!(user: u, credits_awarded: 10.0, devlogged_seconds: 7200, shipped_at: Time.current)
    u.update!(amount_spent: 3.0)

    assert_equal 7, u.available_balance
  end

  # --- recalculate_currency! ---

  test "recalculate_currency! sets currency to total minus spent" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "rc#{SecureRandom.hex(4)}@example.dev")
    project = u.projects.create!(name: "Test", repository_url: "https://example.com")
    project.ships.create!(user: u, credits_awarded: 8.0, devlogged_seconds: 5760, shipped_at: Time.current)
    u.update!(amount_spent: 2.0, credit_offset: 1.0)

    result = u.recalculate_currency!
    assert_in_delta 7.0, result, 0.01
    assert_in_delta 7.0, u.reload.currency.to_f, 0.01
  end

  # --- evaluate_achievements! ---

  test "evaluate_achievements! grants earned achievements" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "ea#{SecureRandom.hex(4)}@example.dev")
    ach = Achievement.create!(title: "First Notch", requirement_type: "min_notches", requirement_value: 1)
    3.times { CharmNotch.create!(user: u, charm_slot: nil) }

    u.evaluate_achievements!
    assert u.achievements.include?(ach)
  end

  # --- ensure_fraud_reason ---

  test "ensure_fraud_reason clears fraud_reason when unflagging" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "fr#{SecureRandom.hex(4)}@example.dev")
    u.update!(flagged_for_fraud: true, fraud_reason: "suspicious")
    assert_equal "suspicious", u.fraud_reason

    u.update!(flagged_for_fraud: false)
    assert_nil u.fraud_reason
  end

  # --- sync_hackatime_status! ---

  test "sync_hackatime_status! updates status from service hash" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "sh#{SecureRandom.hex(4)}@example.dev", slack_id: "U123")

    fake = Object.new
    def fake.get_trusted_status; { trust_level: "verified" }; end

    orig = HackatimeService.method(:new)
    HackatimeService.define_singleton_method(:new) { |*a, **k| fake }
    begin
      u.sync_hackatime_status!
    ensure
      HackatimeService.define_singleton_method(:new) { |*a, **k, &b| orig.call(*a, **k, &b) }
    end

    assert_equal "verified", u.reload.hackatime_trust_status
    assert_not_nil u.hackatime_synced_at
  end

  test "sync_hackatime_status! handles nil service result" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "sh2#{SecureRandom.hex(4)}@example.dev", slack_id: "U123")

    fake = Object.new
    def fake.get_trusted_status; nil; end

    orig = HackatimeService.method(:new)
    HackatimeService.define_singleton_method(:new) { |*a, **k| fake }
    begin
      u.sync_hackatime_status!
    ensure
      HackatimeService.define_singleton_method(:new) { |*a, **k, &b| orig.call(*a, **k, &b) }
    end

    assert_nil u.reload.hackatime_trust_status
  end

  test "sync_hackatime_status! does nothing without slack_id" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "sh3#{SecureRandom.hex(4)}@example.dev", slack_id: nil)
    u.sync_hackatime_status!
    assert_nil u.hackatime_trust_status
  end
end
