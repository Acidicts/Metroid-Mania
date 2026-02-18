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

  test "admin can access index when shop disabled" do
    SiteSetting.set("shop", "false")
    get products_url
    assert_response :success
  ensure
    SiteSetting.set("shop", "true")
  end

  test "non-admin is blocked from index when shop disabled" do
    SiteSetting.set("shop", "false")
    sign_in_as(users(:two))
    get products_url
    assert_redirected_to root_url
    follow_redirect!
    assert_match /Store is currently unavailable/, response.body
  ensure
    SiteSetting.set("shop", "true")
  end
end
