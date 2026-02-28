require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    admin = users(:one)
    admin.update!(role: :admin, email: "admin2@example.com")
    sign_in_as(admin)
  end

  test "should get index" do
    get products_url
    assert_response :success

    # the wishlist container is rendered for the signed‑in admin
    assert_select "div[id^='wishlist_']"

    # when logged in, the add-to-wishlist buttons include the turbo-stream
    # hint so the browser will request a turbo-stream response.
    sign_in_as(users(:one))
    get products_url
    assert_select "form[data-turbo-stream='true']", minimum: 1
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

    # wishlist element should exist (even if empty) and record should now exist
    assert_select "div[id^='wishlist_']"
    assert user.reload.wishlist.present?
  end

  test "wishlist links scroll to products" do
    user = users(:one)
    sign_in_as(user)

    # add a product to the list and hit index
    wl = user.wishlist
    wl.update!(product_ids: [products(:one).id])

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
