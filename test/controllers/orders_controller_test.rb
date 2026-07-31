require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "index redirects non-admin users" do
    get orders_url
    assert_response :redirect
  end

  test "admin can see orders index" do
    sign_in_as(users(:admin))
    get orders_url
    assert_response :success
  end

  test "should get new" do
    product = products(:two)
    # Ensure no pending orders exist for this user+product
    users(:one).orders.where(product: product, status: 0).destroy_all
    users(:one).adjust_charm_notches!(10)
    get new_order_url(product_id: product.id)
    assert_response :success
  end

  test "new redirects when product not found" do
    get new_order_url(product_id: -999)
    assert_response :redirect
  end

  test "new redirects when duplicate pending order exists" do
    product = products(:one)
    get new_order_url(product_id: product.id)
    # Fixture orders(:one) already has a pending order for user one + product one
    assert_response :redirect
  end

  test "should show order" do
    order = orders(:one)
    get order_url(order)
    assert_response :success
  end

  test "non-owner cannot view other user's order" do
    order = orders(:two)
    get order_url(order)
    assert_response :redirect
  end

  test "should update order" do
    order = orders(:one)
    patch order_url(order), params: { order: { status: "paid" } }
    assert_response :redirect
  end

  test "redirects to home when not logged in" do
    get orders_url
    assert_response :redirect
  end
end
