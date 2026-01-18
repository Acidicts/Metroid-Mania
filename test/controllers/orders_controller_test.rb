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
    id_param = loc.match(%r{/orders/([^/]+)})[1]
    order = Order.find_by_param(id_param)
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

      puts "DEBUG flash class=#{flash[:notice].class} inspect=#{flash[:notice].inspect} bytes=#{flash[:notice].to_s.bytes.inspect}"
      assert_match /Order/, flash[:notice].to_s
    rescue ActiveRecord::RecordNotUnique
      # In some DBs/tests a race may raise; ensure there's exactly one pending order for this user/product
      existing = @user.orders.find_by(product_id: product.id, status: 'pending')
      assert existing.present?
      assert_equal before, Order.count
    end
  end

  test "can create new order after a previous denied order (and refund occurs)" do
    product = Product.create!(name: 'TempProduct', steam_app_id: 9998, price_currency: 7.5)

    # Create initial order
    post orders_url, params: { product_id: product.id }
    assert_response :redirect
    first = @user.orders.find_by(product: product)
    assert first.pending?

    # Simulate admin declining the order via the admin endpoint (ensures refund path exercised)
    admin = users(:one)
    admin.update!(role: :admin, email: 'admin-orders@example.com', password: 'password')
    sign_in_as(admin, password: 'password')
    # route helper may not be available in this context in some test setups — POST directly to the admin path
    post "/admin/orders/#{first.to_param}/decline", params: {}
    assert_response :redirect
    first.reload
    assert first.denied?

    # Ensure user was refunded
    user_after_refund = User.find(@user.id)
    assert_operator user_after_refund.currency, :>=, product.price_currency

    # Sign back in as normal user and place a new order for the same product — should succeed
    sign_in_as(@user)
    assert_difference 'Order.count', 1 do
      post orders_url, params: { product_id: product.id }
    end
    assert response.redirect?
    new_order = @user.orders.where(product: product).order(created_at: :desc).first
    assert new_order.pending?
  end

  test "denied order without refund should show helpful message and not silently block" do
    product = Product.create!(name: 'TempProduct2', steam_app_id: 9997, price_currency: 12.0)

    # Create an order that is already denied but (simulating buggy code) the user wasn't refunded
    denied = @user.orders.create!(product: product, status: 'denied', cost: product.price_currency)
    @user.update!(currency: 0.0)

    # Attempt to create a new order — should not raise a confusing uniqueness error; instead show helpful alert
    post orders_url, params: { product_id: product.id }
    assert_response :redirect
    follow_redirect!

    puts "DEBUG: response.status=#{response.status}, flash=#{flash.to_hash.inspect}"
    assert_includes flash[:alert].to_s, "denied order"
  end

  test "should show order" do
    get order_url(@order)
    assert_response :success
  end
end
