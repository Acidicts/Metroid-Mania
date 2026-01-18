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

  test "delete refunds missing refund and destroys denied order" do
    # Create a denied order that hasn't been refunded (simulate buggy past state)
    prod = Product.create!(name: 'DeleteTest', steam_app_id: 55, price_currency: 3.0)
    denied = users(:one).orders.create!(product: prod, status: 'denied', cost: prod.price_currency)

    # Ensure there's no refund audit yet (DB-specific JSON expression)
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('sqlite')
      Audit.where("action = ? AND json_extract(details, '$.order_id') = ?", 'order_refunded', denied.id.to_s).delete_all
    else
      Audit.where("action = ? AND (details ->> 'order_id')::text = ?", 'order_refunded', denied.id.to_s).delete_all
    end

    user_before = denied.user.currency || 0

    post delete_admin_order_url(denied)

    assert_redirected_to admin_orders_url
    assert_not Order.exists?(denied.id)
    assert_equal user_before + denied.cost.to_f, denied.user.reload.currency
    assert_audit_created(action: 'order_refunded', project: nil, user: @admin)
    assert_audit_created(action: 'order_deleted', project: nil, user: @admin)
  end

  test "delete on already-refunded denied order just destroys" do
    prod = Product.create!(name: 'DeleteTest2', steam_app_id: 56, price_currency: 4.0)
    denied = users(:one).orders.create!(product: prod, status: 'denied', cost: prod.price_currency)

    # Insert a refund audit to simulate previous refund
    Audit.create!(user: @admin, project: nil, action: 'order_refunded', details: { order_id: denied.id, amount: denied.cost.to_f, previous_status: 'pending' })

    post delete_admin_order_url(denied)

    assert_redirected_to admin_orders_url
    assert_not Order.exists?(denied.id)
    assert_audit_created(action: 'order_deleted', project: nil, user: @admin)
  end

  test "missing order redirects with alert" do
    non_existent = Order.maximum(:id).to_i + 100

    # GET show
    get admin_order_url(non_existent)
    assert_redirected_to admin_orders_url
    assert_match /Order not found/, flash[:alert]

    # POSTful actions should behave the same
    post fulfill_admin_order_url(non_existent)
    assert_redirected_to admin_orders_url
    assert_match /Order not found/, flash[:alert]
  end

  test "index search by public_id and id works" do
    prod = Product.create!(name: 'SearchTest', steam_app_id: 77, price_currency: 2.0)
    u = users(:one)
    u.update!(currency: 100.0)
    o1 = u.orders.create!(product: prod)

    # search by public_id
    get admin_orders_url(q: o1.public_id)
    assert_response :success
    assert_match o1.public_id, response.body

    # search by numeric id
    get admin_orders_url(q: o1.id.to_s)
    assert_response :success
    assert_match o1.public_id, response.body
  end
end
