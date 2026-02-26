require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  # The helpers we're interested in are defined on the controller and exposed to
  # views via +helper_method+.  We can exercise them directly by instantiating a
  # fresh controller object; they don't depend on request/response state.

  test "user_has_prize? returns false for nil and users without a prize" do
    assert_not ApplicationController.new.user_has_prize?(nil)

    user = users(:one)
    # make sure there are no existing prize orders for this user
    Order.where(user: user, product: WeeklyGoalService.prize_product).delete_all

    assert_not ApplicationController.new.user_has_prize?(user)
  end

  test "user_has_prize? returns true when a pending prize order exists" do
    user = users(:one)
    prize = WeeklyGoalService.prize_product
    Order.create!(user: user, product: prize, status: "pending", cost: 0)

    assert ApplicationController.new.user_has_prize?(user)
  end

  test "user_has_prize? handles orders pointing to an uppercase-named product" do
    user = users(:one)
    prod = Product.create!(name: "Prize", price_currency: 0, notch_cost: 0,
                           stock: 0, show: false)
    Order.create!(user: user, product: prod, status: "pending", cost: 0)

    # helper should still detect it regardless of casing
    assert ApplicationController.new.user_has_prize?(user)
    assert_equal prod.id, ApplicationController.new.prize_order_for(user).product_id
  end

  test "prize_order_for returns the matching record or nil" do
    user = users(:one)
    prize = WeeklyGoalService.prize_product

    # no order yet
    assert_nil ApplicationController.new.prize_order_for(user)

    order = Order.create!(user: user, product: prize, status: "pending", cost: 0)
    assert_equal order, ApplicationController.new.prize_order_for(user)
  end
end
