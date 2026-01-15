require "test_helper"

class MetroidmaniaControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get metroidmania_index_url
    assert_response :success
  end
end
