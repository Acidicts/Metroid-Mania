require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    admin = users(:one)
    admin.update!(role: :admin, email: 'admin2@example.com')
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
end
