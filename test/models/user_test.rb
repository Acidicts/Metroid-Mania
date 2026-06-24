require "test_helper"
require "securerandom"

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
    # association should start empty
    assert_equal 0, u.charm_slots.count

    # use raw attribute assignment to exercise numeric validations (association
    # setter would treat the value as a collection)
    # write directly to the column to avoid hitting the association setter
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

    # reload from database should trigger the callback and create slots
    u2 = User.find(u.id)
    assert_equal 2, u2.charm_slots.count
    assert u2.charm_slots.all? { |s| s.user_id == u2.id }
    # slot objects should be created without an associated order by default
    assert u2.charm_slots.all? { |s| s.order.nil? }
  end

  test "wishlist association exists and is built automatically" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "w#{SecureRandom.hex(4)}@example.dev")
    # after create the wishlist should exist and be tied to the user
    assert u.wishlist.present?, "expected new user to have a wishlist"
    assert_equal u.id, u.wishlist.user_id

    # accessing wishlist should always return a persisted record
    u.wishlist.destroy!
    assert u.reload.wishlist.persisted?
  end

  test "subsequent loads only create the gap not duplicate existing slots" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")
    u.update_column(:charm_slots, 1)
    u2 = User.find(u.id)
    # bumping the attribute doesn't immediately add slots until reload
    assert_equal 1, u2.charm_slots.count

    # increase the column again and reload; only the new gap should be filled
    u.update_column(:charm_slots, 3)
    u3 = User.find(u.id)
    assert_equal 3, u3.charm_slots.count
  end

  test "level and progress calculations with increasing thresholds" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "lvl#{SecureRandom.hex(4)}@example.dev")

    # no xp -> level 1, no progress
    u.update_column(:xp, 0)
    assert_equal [ 1, 0 ], u.get_level
    assert_equal 0.0, u.get_level_progress_dec

    # halfway to level 2
    u.update_column(:xp, 50)
    assert_equal [ 1, 50 ], u.get_level
    assert_equal 0.5, u.get_level_progress_dec

    # exactly enough for level 2
    u.update_column(:xp, 100)
    assert_equal [ 2, 0 ], u.get_level
    assert_equal 0.0, u.get_level_progress_dec

    # just below level 3 (requires 100 + 200 = 300 total)
    u.update_column(:xp, 299)
    assert_equal [ 2, 199 ], u.get_level
    assert_in_delta 0.995, u.get_level_progress_dec, 0.001

    # enough to be in level 3
    u.update_column(:xp, 350)
    # total thresholds consumed: 100 + 200 = 300; remaining 50 in level 3
    assert_equal [ 3, 50 ], u.get_level
    assert_equal (50.0 / 300.0).round(2), u.get_level_progress_dec
  end

  test "xp is derived from project devlogged time and persisted on save" do
    user = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "xp#{SecureRandom.hex(4)}@example.dev")
    project = user.projects.create!(name: "Test", repository_url: "https://example.com", total_seconds: 10_000)

    # no devlogs => xp should be zero
    assert_equal 0, user.get_xp
    assert_equal 0, user.xp

    # create a devlog belonging to another user (should not count)
    other = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "o#{SecureRandom.hex(4)}@example.dev")
    project.devlogs.create!(user: other, duration_seconds: 3_600)
    assert_equal 0, user.get_xp

    # create a legitimate devlog for this project
    project.devlogs.create!(user: user, duration_seconds: 7_200)
    # two hours = 120 minutes
    assert_equal 120, user.get_xp
    assert_equal 120, user.xp

    # saving the user should also update xp via validation hook
    user.update!(name: "Updated")
    assert_equal 120, user.reload.xp
  end

  # --- Superadmin assignment tests ---

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
end
