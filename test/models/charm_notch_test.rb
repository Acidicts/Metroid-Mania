require "test_helper"

class CharmNotchTest < ActiveSupport::TestCase
  setup do
    # make sure there's a user available for associations; fixtures may
    # already provide one, but fall back to creating one manually.
    @user = (defined?(users) && users(:one)) || User.create!(name: "test user", email: "test@example.com")

    # create a bare charm_slot - order_id intentionally nil
    @empty_slot = CharmSlot.create!(user: @user)

    # build an order (Order requires a product association) but we don't
    # care about business rules so disable callbacks/validations.
    product = Product.create!(name: "test")
    if defined?(Order)
      @order = Order.new(user: @user, product: product)
      @order.save!(validate: false)
    end

    # slot with an order so clearing shouldn't happen
    @filled_slot = CharmSlot.create!(user: @user, order: @order)
  end

  test "assigned? matches presence of slot" do
    notch = CharmNotch.new(user: @user)
    assert_not notch.assigned?
    notch.charm_slot = @empty_slot
    assert notch.assigned?
  end

  test "slot is cleared before validation when order_id is missing" do
    notch = CharmNotch.new(user: @user, charm_slot: @empty_slot)
    assert notch.valid?            # triggers the before_validation callback
    assert_nil notch.charm_slot     # should have been cleared in memory
  end

  test "slot is preserved if order_id present" do
    notch = CharmNotch.new(user: @user, charm_slot: @filled_slot)
    assert notch.valid?
    assert_equal @filled_slot, notch.charm_slot
  end

  test "creating a notch reevaluates achievements for the user" do
    # ensure there's an achievement minimum that will trigger
    ach = Achievement.create!(title: "Min notches 1", requirement_type: "min_notches", requirement_value: 1)
    @user.achievements.delete_all

    assert_not @user.achievements.include?(ach)
    # creating a notch should fire the callback and award the badge
    @user.charm_notches.create!(user: @user)
    assert @user.achievements.reload.include?(ach)
  end

  test "destroying a notch still leaves existing achievements" do
    # once awarded, achievements are not revoked when the underlying
    # condition later drops below the threshold
    ach = Achievement.create!(title: "Min notches 1", requirement_type: "min_notches", requirement_value: 1)
    @user.achievements.delete_all
    @user.charm_notches.create!(user: @user)
    @user.achievements.reload
    assert @user.achievements.include?(ach)

    # destroy the notch - achievement remains
    @user.charm_notches.last.destroy
    @user.achievements.reload
    assert @user.achievements.include?(ach)
  end
end
