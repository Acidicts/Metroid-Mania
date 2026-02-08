require "test_helper"
require "securerandom"

class UserTest < ActiveSupport::TestCase
  test "set_region_from_ip persists region when service returns a value" do
    u = User.create!(uid: SecureRandom.hex(6), provider: 'test', email: "t#{SecureRandom.hex(4)}@example.dev")

    fake = Object.new
    def fake.get_region_by_ip; 'EU'; end

    orig = HackclubIpService.method(:new)
    HackclubIpService.define_singleton_method(:new) { |*a, **k| fake }
    begin
      u.set_region_from_ip('1.2.3.4')
    ensure
      HackclubIpService.define_singleton_method(:new) { |*a, &b| orig.call(*a, &b) }
    end

    assert_equal 'EU', u.reload.region
  end

  test "set_region_from_ip returns nil and does not change when service returns nil" do
    u = User.create!(uid: SecureRandom.hex(6), provider: 'test', email: "t#{SecureRandom.hex(4)}@example.dev")

    fake = Object.new
    def fake.get_region_by_ip; nil; end

    orig = HackclubIpService.method(:new)
    HackclubIpService.define_singleton_method(:new) { |*a, **k| fake }
    begin
      assert_nil u.set_region_from_ip('1.2.3.4')
    ensure
      HackclubIpService.define_singleton_method(:new) { |*a, &b| orig.call(*a, &b) }
    end

    assert_nil u.reload.region
  end
end
