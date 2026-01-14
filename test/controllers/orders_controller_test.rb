require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @order = orders(:one)
    @user = users(:one)
    # ensure the test user has an email for dev sign-in and sufficient balance
    @user.update!(email: 'user@example.com', currency: 100.0)
    sign_in_as(@user)
  end

  test "should get index" do
    get orders_url
    assert_response :success
  end

  test "should create order" do
    # choose a product the user does not already have a pending order for
    product = products(:two)

    before = Order.count
    post orders_url, params: { product_id: product.id }
    after = Order.count
    puts "DEBUG: before=#{before} after=#{after} diff=#{after-before}"

    assert_operator (after - before), :>=, 1

    assert response.redirect?
    loc = response.location
    id = loc.match(%r{/orders/(\d+)})[1].to_i
    order = Order.find(id)
    assert_equal product.id, order.product_id
    assert_equal @user.id, order.user_id
  end

  test "should show order" do
    get order_url(@order)
    assert_response :success
  end
end
