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
    # choose a brand new product so test avoids fixture collisions
    product = Product.create!(name: 'TempProduct', steam_app_id: 9999, price_currency: 5.0)
    puts "DEBUG product id=#{product.id} name=#{product.name}"

    # debug: list existing orders
    puts "DEBUG ORDERS BEFORE: #{Order.all.map { |o| [o.id, o.user&.email, o.product&.id, o.product&.name, o.status] }.inspect }"

    # Ensure no pending order exists for this user/product before we start
    @user.orders.where(product: product, status: 'pending').destroy_all

    assert_difference 'Order.count', 1 do
      post orders_url, params: { product_id: product.id }
    end

    assert response.redirect?
    loc = response.location
    id = loc.match(%r{/orders/(\d+)})[1].to_i
    order = Order.find(id)
    assert_equal product.id, order.product_id
    assert_equal @user.id, order.user_id

  end

  test "should not create duplicate pending order" do
    product = Product.create!(name: 'TempProduct', steam_app_id: 9999, price_currency: 5.0)

    # First request should create the order
    post orders_url, params: { product_id: product.id }
    assert_response :redirect

    before = Order.count
    begin
      # Second request for the same product should not create a new pending order
      post orders_url, params: { product_id: product.id }
      after = Order.count

      assert_equal before, after, "Duplicate pending order was created"
      assert response.redirect?
      follow_redirect!
      assert_includes flash[:notice], "Order"
    rescue ActiveRecord::RecordNotUnique
      # In some DBs/tests a race may raise; ensure there's exactly one pending order for this user/product
      existing = @user.orders.find_by(product_id: product.id, status: 'pending')
      assert existing.present?
      assert_equal before, Order.count
    end
  end

  test "should show order" do
    get order_url(@order)
    assert_response :success
  end
end
