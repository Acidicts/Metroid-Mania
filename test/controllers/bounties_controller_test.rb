require "test_helper"

class BountiesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get bounties_index_url
    assert_response :success
  end

  test "should get show" do
    get bounties_show_url
    assert_response :success
  end

  test "should get new" do
    get bounties_new_url
    assert_response :success
  end

  test "should get edit" do
    get bounties_edit_url
    assert_response :success
  end

  test "should get _form" do
    get bounties__form_url
    assert_response :success
  end
end
