require "test_helper"

class AddressControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should create address" do
    assert_difference("Address.count") do
      post addresses_url, params: { address: { address_line_1: "123 Main St", city: "Springfield", province: "IL", postal_code: "62704", country: "US - United States" } }
    end
    assert_response :redirect
  end

  test "create with empty params still redirects" do
    post addresses_url, params: { address: { address_line_1: nil, city: nil } }
    assert_response :redirect
  end

  test "should create address via JSON" do
    assert_difference("Address.count") do
      post addresses_url(format: :json), params: { address: { address_line_1: "456 Oak Ave", city: "Portland", province: "OR", postal_code: "97201", country: "US - United States" } }
    end
    assert_response :success
    json = JSON.parse(@response.body)
    assert json["success"]
  end

  test "should destroy address" do
    addr = addresses(:one)
    assert_difference("Address.count", -1) do
      delete address_url(addr)
    end
    assert_response :redirect
  end

  test "should destroy address via JSON" do
    addr = addresses(:one)
    assert_difference("Address.count", -1) do
      delete address_url(addr, format: :json)
    end
    assert_response :success
  end
end
