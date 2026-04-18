require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    admin = users(:one)
    admin.update!(role: :admin, email: "admin2@example.com", password: "password")
    # login using password to ensure same record is used (dev_login would create a new user)
    sign_in_as(admin, password: "password")
    # ensure wishlist exists for the logged-in user so index renders container
    admin.reload
    admin.ensure_wishlist if admin.respond_to?(:ensure_wishlist)
  end

  test "should get index" do
    get products_url
    assert_response :success

    # make sure admin has a non-empty wishlist so the container actually shows up
    admin = users(:one)
    admin.wishlist.update!(product_ids: [ @product.id ])
    get products_url
    assert_response :success
    assert_select "turbo-frame[id^='wishlist_']" # wishlist frame rendered

    # when logged in, the add-to-wishlist buttons include the turbo-stream
    # hint so the browser will request a turbo-stream response.
    sign_in_as(users(:one))
    get products_url
    assert_select "form[data-turbo-stream='true']", minimum: 1
  end

  test "product card shows discounted notch cost during active sale" do
    SiteSetting.set(:shop, true) if defined?(SiteSetting)

    product = Product.create!(name: "SaleItem", steam_app_id: 123, price_currency: 0.0, notch_cost: 4)
    Sale.create!(name: "NotchSale", discount_notches: 2, product: product, quantity: 1, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)

    get products_url
    assert_response :success
    assert_select "div##{dom_id(product)}" do
      assert_select "p", text: /Notches:\s*2/ # effective cost displayed
      assert_select "p", text: /\(4\)/, minimum: 1 # original cost in parentheses
    end

    # also test a one-notch discount scenario
    product2 = Product.create!(name: "SaleItem2", steam_app_id: 124, price_currency: 0.0, notch_cost: 3)
    Sale.create!(name: "OneOff", discount_notches: 1, product: product2, quantity: 1, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
    get products_url
    assert_select "div##{dom_id(product2)}" do
      assert_select "p", text: /Notches:\s*2/ # 3 minus 1 = 2
      assert_select "p", text: /\(3\)/
    end
  end

  test "admin link appears only for admins" do
    # first, visit as admin (already signed in by setup)
    get products_url
    assert_select "a", text: /New product/ # rails' assert_select can match link

    # now sign in as regular user and confirm link is absent
    sign_in_as(users(:two))
    get products_url
    assert_response :success
    assert_select "a", text: /New product/, count: 0
  end

  test "should get new" do
    get new_product_url
    assert_response :success
  end

  test "should create product" do
    assert_difference("Product.count") do
      post products_url, params: { product: { name: @product.name, price_currency: @product.price_currency, steam_app_id: @product.steam_app_id, steam_price_cents: @product.steam_price_cents } }
    end

    assert_redirected_to product_url(Product.last)
  end

  test "should create product with uploaded image" do
    tmp = create_sample_image("product_upload.png")
    fake = { "url" => "https://cdn.hackclub.com/abcd/product_upload.png" }

    orig = CdnService.method(:upload)
    CdnService.define_singleton_method(:upload) { |_f| fake }
    begin
      assert_difference("Product.count") do
        post products_url, params: { product: { name: "WithImage", price_currency: 1.23, image_file: fixture_file_upload(tmp, "image/png") } }
      end

      p = Product.last
      assert_equal "https://cdn.hackclub.com/abcd/product_upload.png", p.image_url
    ensure
      CdnService.define_singleton_method(:upload) { |*a, &b| orig.call(*a, &b) }
    end
  end

  test "should show product" do
    get product_url(@product)
    assert_response :success
  end

  test "should get edit" do
    get edit_product_url(@product)
    assert_response :success
  end

  test "edit form shows existing accessory groups and accessories" do
    product = Product.create!(name: "WithAccessories", price_currency: 2.99, steam_app_id: 999)
    group = AccessoryGroup.create!(product: product, name: "Color")
    Accessory.create!(accessory_group: group, name: "Green")

    get edit_product_url(product)
    assert_response :success
    assert_select "input[name='product[accessory_groups_attributes][0][name]'][value='Color']"
    assert_select "input[name='product[accessory_groups_attributes][0][accessories_attributes][0][name]'][value='Green']"
  end

  test "should update product" do
    patch product_url(@product), params: { product: { name: @product.name, price_currency: @product.price_currency, steam_app_id: @product.steam_app_id, steam_price_cents: @product.steam_price_cents } }
    assert_redirected_to product_url(@product)
  end

  test "should destroy product" do
    # create a new product without orders
    p = Product.create!(name: "Temp", price_currency: 0.99, steam_app_id: nil)

    assert_difference("Product.count", -1) do
      delete product_url(p)
    end

    assert_redirected_to products_url
  end

  test "should not destroy product with existing orders" do
    # ensure there really is an order for the fixture product and the user has notches
    u = users(:one)
    u.adjust_charm_notches!(10)
    # create a non-pending order so validations don't complain
    Order.create!(user: u, product: products(:one), status: "denied", cost: products(:one).price_currency)

    assert_no_difference("Product.count") do
      delete product_url(products(:one))
    end

    assert_redirected_to product_url(products(:one))
    assert_match /Cannot delete product/, flash[:warning]
  end

  test "admin can access index when shop disabled" do
    SiteSetting.set("shop", "false")
    get products_url
    assert_response :success
  ensure
    SiteSetting.set("shop", "true")
  end

  test "non-admin user with no wishlist can view index" do
    # previously this path would blow up when rendering the partial.
    user = users(:two)
    sign_in_as(user)
    get products_url
    assert_response :success

    # wishlist record should be created; partial may not render until items are added
    assert user.reload.wishlist.present?
  end

  test "wishlist links scroll to products" do
    user = users(:one)
    sign_in_as(user)

    # add a product to the list and hit index
    wl = user.wishlist
    wl.update!(product_ids: [ products(:one).id ])

    get products_url
    assert_response :success

    # there should be an anchor pointing at the product card id
    assert_select "a[href='##{dom_id(products(:one))}']"

    # removal button should be present as well (action may include query params)
    assert_select "form[action^='#{remove_product_wishlist_path(wl)}']"
  end

  test "non-admin is blocked from index when shop disabled" do
    SiteSetting.set("shop", "false")
    sign_in_as(users(:two))
    get products_url
    assert_redirected_to root_url
    follow_redirect!
    assert_match /Store is currently disabled/, response.body
  ensure
    SiteSetting.set("shop", "true")
  end

  test "banner appears for running disabled on product index" do
    SiteSetting.set("running", "false")
    get products_url
    assert_response :success
    assert_match /This ysws is not active/, response.body
    assert_match /RSVP/, response.body
  ensure
    SiteSetting.set("running", "true")
  end
end
