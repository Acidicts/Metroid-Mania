require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: 'admin-orders@example.com', password: 'password')
    sign_in_as(@admin, password: 'password')

    @order = orders(:one)
  end

  test "fulfill marks order shipped and records audit" do
    post fulfill_admin_order_url(@order)

    assert_redirected_to admin_orders_url
    assert_equal 'shipped', @order.reload.status
    assert_audit_created(action: 'order_fulfilled', project: nil, user: @admin)
  end

  test "decline refunds user and records audit" do
    user_before = @order.user.currency || 0

    post decline_admin_order_url(@order)

    assert_redirected_to admin_orders_url
    assert_equal 'denied', @order.reload.status
    assert_equal user_before + @order.cost.to_f, @order.user.reload.currency
    assert_audit_created(action: 'order_refunded', project: nil, user: @admin)
  end
end
