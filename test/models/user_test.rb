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
      HackclubIpService.define_singleton_method(:new) { |*a, &b| orig.call(*a, &b) }
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
      HackclubIpService.define_singleton_method(:new) { |*a, &b| orig.call(*a, &b) }
    end

    assert_nil u.reload.region
  end

  test "charm_slots defaults to zero and validates nonnegative integer" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev")
    assert_equal 0, u.charm_slots

    u.charm_slots = -1
    assert_not u.valid?
    assert_includes u.errors[:charm_slots], "must be greater than or equal to 0"

    u.charm_slots = 1.5
    assert_not u.valid?
    assert_includes u.errors[:charm_slots], "must be an integer"

    u.charm_slots = 3
    assert u.valid?
  end

  test "loading a user creates any missing charm slot records" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev", charm_slots: 2)
    # newly created record doesn't trigger after_find yet
    assert_equal 0, u.charm_slots.count

    # reload from database should trigger the callback and create slots
    u2 = User.find(u.id)
    assert_equal 2, u2.charm_slots.count
    assert u2.charm_slots.all? { |s| s.user_id == u2.id }
    # slot objects should be created without an associated order by default
    assert u2.charm_slots.all? { |s| s.order.nil? }
  end

  test "subsequent loads only create the gap not duplicate existing slots" do
    u = User.create!(uid: SecureRandom.hex(6), provider: "test", email: "t#{SecureRandom.hex(4)}@example.dev", charm_slots: 1)
    u2 = User.find(u.id)
    assert_equal 1, u2.charm_slots.count

    u2.update!(charm_slots: 3)
    # bumping the attribute doesn't immediately add slots until reload
    assert_equal 1, u2.charm_slots.count

    u3 = User.find(u.id)
    assert_equal 3, u3.charm_slots.count
  end
end
