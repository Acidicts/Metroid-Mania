require "test_helper"

class Admin::SalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @sale = sales(:one)
    @product = products(:one) rescue Product.create!(name: "Notches")
  end

  test "should get index" do
    sign_in_as(@admin)
    get admin_sales_url
    assert_response :success
  end

  test "should get show" do
    sign_in_as(@admin)
    get admin_sale_url(@sale)
    assert_response :success
  end

  test "should get new" do
    sign_in_as(@admin)
    get new_admin_sale_url
    assert_response :success
  end

  test "should create sale" do
    sign_in_as(@admin)
    assert_difference("Sale.count") do
      post admin_sales_url, params: { sale: { name: "Black Friday", discount_notches: 5, product_id: @product.id, quantity: 10 } }
    end
    assert_redirected_to admin_sales_path
    created = Sale.last
    assert_equal @product, created.product
    assert_equal 10, created.quantity
  end

  test "should get edit" do
    sign_in_as(@admin)
    get edit_admin_sale_url(@sale)
    assert_response :success
  end

  test "should update sale" do
    sign_in_as(@admin)
    patch admin_sale_url(@sale), params: { sale: { name: "Updated", product_id: @product.id, quantity: 2 } }
    assert_redirected_to admin_sales_path
    @sale.reload
    assert_equal "Updated", @sale.name
    assert_equal @product, @sale.product
    assert_equal 2, @sale.quantity
  end

  test "should destroy sale" do
    sign_in_as(@admin)
    assert_difference("Sale.count", -1) do
      delete admin_sale_url(@sale)
    end
    assert_redirected_to admin_sales_path
  end
end
