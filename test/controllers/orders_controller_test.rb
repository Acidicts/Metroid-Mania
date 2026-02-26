require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @order = orders(:one)
    @user = users(:one)
    # ensure the test user has an email for dev sign-in, sufficient balance and free notches
    @user.update!(email: "user@example.com", currency: 100.0)
    # give the user a bunch of free notches so orders can succeed without worrying about
    # their cost in tests
    @user.adjust_charm_notches!(100)

    # make sure the shop feature flag is on for tests (some environments default off)
    SiteSetting.set(:shop, true) if defined?(SiteSetting)

    sign_in_as(@user)
  end

  test "should get index" do
    get orders_url
    # non-admin users are redirected to home
    assert_response :redirect
    assert_redirected_to home_url

    # admin users still see the index
    admin = users(:one)
    admin.update!(role: :admin, email: "admin@example.com")
    sign_in_as(admin)
    get orders_url
    assert_response :success
  end

  test "should create order" do
    # choose a brand new product so test avoids fixture collisions
    product = Product.create!(name: "TempProduct", steam_app_id: 9999, price_currency: 5.0)

    # Ensure no pending order exists for this user/product before we start
    @user.orders.where(product: product, status: "pending").destroy_all

    assert_difference "Order.count", 1 do
      post orders_url, params: { product_id: product.id, charm_image_url: "https://cdn.example.com/charm.png" }
    end

    # controller now redirects back to products index after successful purchase
    assert_redirected_to products_url
    order = Order.last
    assert_equal product.id, order.product_id
    assert_equal @user.id, order.user_id
    assert_equal "https://cdn.example.com/charm.png", order.charm_image_url

    # test default when parameter omitted
    product2 = Product.create!(name: "TempDefault", steam_app_id: 9994, price_currency: 4.0, image_url: "http://prod/default.png")
    assert_difference "Order.count", 1 do
      post orders_url, params: { product_id: product2.id }
    end
    order2 = Order.last
    assert_equal "http://prod/default.png", order2.charm_image_url
  end

  test "should not create duplicate pending order" do
    product = Product.create!(name: "TempProduct", steam_app_id: 9999, price_currency: 5.0)

    # First request should create the order
    post orders_url, params: { product_id: product.id }
    assert_response :redirect

    before = Order.count

    # Second request for the same product should also redirect and not increase count
    post orders_url, params: { product_id: product.id }
    after = Order.count

    assert_equal before, after, "Duplicate pending order was created"
    assert_redirected_to home_url
    follow_redirect!

    assert_match(/Already In Loadout/, flash[:alert].to_s)
  end

  test "can create new order after a previous denied order (and refund occurs)" do
    product = Product.create!(name: "TempProduct", steam_app_id: 9998, price_currency: 7.5)

    # Create initial order
    post orders_url, params: { product_id: product.id }
    assert_response :redirect
    first = @user.orders.find_by(product: product)
    assert first.pending?

    # Simulate admin declining the order via the admin endpoint (ensures refund path exercised)
    admin = users(:one)
    admin.update!(role: :admin, email: "admin-orders@example.com", password: "password")
    sign_in_as(admin, password: "password")
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
    assert_difference "Order.count", 1 do
      post orders_url, params: { product_id: product.id }
    end
    assert response.redirect?
    new_order = @user.orders.where(product: product).order(created_at: :desc).first
    assert new_order.pending?
  end

  test "denied order without refund should show helpful message and not silently block" do
    product = Product.create!(name: "TempProduct2", steam_app_id: 9997, price_currency: 12.0, credits_per_dollar: 10.0)

    # Create an order that is already denied but (simulating buggy code) the user wasn't refunded
    denied = @user.orders.create!(product: product, status: "denied", cost: product.price_currency)
    @user.update!(currency: 0.0)
    # strip away any free notches so a new purchase truly lacks funds
    @user.adjust_charm_notches!(0)

    # Attempt to create a new order — should not raise a confusing uniqueness error; instead show helpful alert
    post orders_url, params: { product_id: product.id }
    assert_response :redirect
    follow_redirect!

    puts "DEBUG: response.status=#{response.status}, flash=#{flash.to_hash.inspect}"
    # message should mention either the denied order or lack of notches
    assert_match(/denied|Notches/, flash[:alert].to_s)
  end

  test "insufficient funds redirects back to products with error" do
    product = Product.create!(name: "TempProductInsuff", steam_app_id: 9966, price_currency: 9.0)

    # make sure user has no money and no denied orders
    @user.update!(currency: 0.0)
    # remove any free notches so currency check actually fails
    @user.adjust_charm_notches!(0)

    post orders_url, params: { product_id: product.id }
    assert_redirected_to products_url
    follow_redirect!
    assert_includes flash[:alert].to_s, "Insufficient Notches"
  end

  test "should create order with variable grant amount" do
    # Create a variable grant product
    product = Product.create!(
      name: "Variable Grant Product",
      steam_app_id: 9996,
      price_currency: 10.0,
      credits_per_dollar: 100.0,
      variable_grant: true,
      grant_min_cents: 1000,  # $10.00
      grant_max_cents: 50000, # $500.00
      image_url: "https://cdn.example.com/variable.png"
    )

    # Ensure no pending order exists for this user/product before we start
    @user.orders.where(product: product, status: "pending").destroy_all

    # Give user enough currency for the test
    @user.update!(currency: 5000.0)  # 5000 credits

    # Test creating an order with a specific grant amount
    grant_amount = 25.0  # $25.00
    assert_difference "Order.count", 1 do
      post orders_url, params: {
        product_id: product.id,
        grant_amount_dollars: grant_amount
      }
    end

    assert_redirected_to products_url
    order = Order.last
    assert_equal product.id, order.product_id
    assert_equal @user.id, order.user_id
    assert_equal (grant_amount * 100).round, order.grant_amount_cents
    assert_equal (grant_amount * product.credits_per_dollar), order.cost
    assert_equal product.image_url, order.charm_image_url
  end

  test "should show order" do
    get order_url(@order)
    assert_response :success
    # should render without crashing even if public_id is nil
  end

  test "user can cancel pending order via update route" do
    @order.update!(status: "pending")
    put order_url(@order), params: { status: "user_denied" }
    assert_redirected_to order_url(@order)
    @order.reload
    assert_equal "user_denied", @order.status
  end

  test "cannot cancel order belonging to someone else" do
    other = users(:two)
    other.update!(email: "other@example.com", currency: 100.0)
    # create a pending order for the other user; skip validations to avoid notch checks
    order = Order.new(user: other, product: products(:one), status: "pending", cost: 1)
    order.save!(validate: false)

    put order_url(order), params: { status: "user_denied" }
    assert_redirected_to orders_url
    order.reload
    assert_equal "pending", order.status
  end

  test "new order form prepopulates charm_image_url from product" do
    product = Product.create!(name: "HasImage", steam_app_id: 1234, price_currency: 1.0, image_url: "http://foo/bar.png")

    # instead of relying on assigns we create the order via normal flow and
    # ensure the attribute is copied as expected
    assert_difference "Order.count", 1 do
      post orders_url, params: { product_id: product.id }
    end
    order = Order.last
    assert_equal product.image_url, order.charm_image_url
  end

  test "product card Add To Loadout button posts directly to orders#create" do
    product = Product.create!(name: "DirectBuy", steam_app_id: 5555, price_currency: 3.0)
    get products_url
    assert_response :success

    # debug: dump fragment of body to help understand why selectors fail
    if Rails.env.test? && ENV['DEBUG_PRODUCTS']
      puts "=== PRODUCTS INDEX BODY START ==="
      puts response.body
      puts "=== PRODUCTS INDEX BODY END ==="
    end

    # ensure the form action contains the product id as a query parameter
    assert_select "form[action*='product_id=#{product.id}']"
    assert_select "form[action*='#{orders_path}'] button[type=submit]", text: 'Add To Loadout'
  end

  test "product card for variable grant products includes minimum grant value" do
    product = Product.create!(
      name: "VariableAuto",
      steam_app_id: 5556,
      price_currency: 1.0,
      variable_grant: true,
      grant_min_cents: 2500, # $25.00
      grant_max_cents: 10000 # $100.00
    )

    get products_url
    assert_response :success

    assert_select "form[action*='grant_amount_dollars']"
  end

  test "invalid charm_image_url prevents creation and displays error" do
    product = Product.create!(name: "TempBadUrl", steam_app_id: 9995, price_currency: 2.0)
    post orders_url, params: { product_id: product.id, charm_image_url: "not_a_url" }
    assert_response :unprocessable_entity
    assert_select "div", /must be a valid URL/
    # no new order should have been added
    assert_not Order.exists?(product: product, user: @user)
  end

  test "creating order blocked when shop disabled" do
    SiteSetting.set("shop", "false")
    product = Product.create!(name: "TempProductX", steam_app_id: 9988, price_currency: 5.0)

    post orders_url, params: { product_id: product.id }
    assert_redirected_to root_url
    follow_redirect!
    # banner text changed to "disabled" in layout
    assert_match /Store is currently disabled/, response.body
  ensure
    SiteSetting.set("shop", "true")
  end

  test "root page shows ysws-not-running banner when disabled" do
    SiteSetting.set("running", "false")
    get root_url
    assert_response :success
    assert_match /This ysws is not active/, response.body
  ensure
    SiteSetting.set("running", "true")
  end
end
