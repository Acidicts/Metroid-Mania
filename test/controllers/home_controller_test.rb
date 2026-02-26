require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get home_index_url
    assert_response :success
  end

  test "prize banner appears when user has pending prize" do
    user = users(:one)
    prize = WeeklyGoalService.prize_product
    Order.create!(user: user, product: prize, status: "pending", cost: 0)

    sign_in_as(user)
    get home_index_url
    assert_response :success
    assert_match /You have won the weekly goal prize/, response.body
    assert_match /View your prize/, response.body
  end

  test "banner still shows if prize order uses uppercase product name" do
    user = users(:one)
    prod = Product.create!(name: "Prize", price_currency: 0, notch_cost: 0,
                           stock: 0, show: false)
    Order.create!(user: user, product: prod, status: "pending", cost: 0)

    sign_in_as(user)
    get home_index_url
    assert_response :success
    assert_match /You have won the weekly goal prize/, response.body
  end

  test "prize banner absent when user has no prize" do
    user = users(:one)
    sign_in_as(user)
    get home_index_url
    assert_response :success
    assert_no_match /You have won the weekly goal prize/, response.body
  end
end
