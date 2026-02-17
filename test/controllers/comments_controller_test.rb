require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @comment = comments(:one)
  end

  test "should get index" do
    get comments_url
    assert_response :success
  end

  test "should get new" do
    get new_comment_url
    assert_response :success
  end

  test "should create comment" do
    sign_in_as(users(:one))

    assert_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Hello" } }
    end

    assert_redirected_to root_url
    assert_match /Comment created/, flash[:notice]
  end

  test "non-admin cannot create ship comment" do
    sign_in_as(users(:two))

    assert_no_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Not allowed", ship_id: ships(:one).id } }
    end

    assert_redirected_to root_url
    assert_match /Only admins/, flash[:alert]
  end

  test "admin can create ship comment" do
    admin = users(:admin)
    admin.update!(role: :admin)
    sign_in_as(admin)

    assert_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Admin comment", ship_id: ships(:one).id } }
    end

    assert_redirected_to root_url
    assert_match /Comment created/, flash[:notice]
  end

  test "should show comment" do
    get comment_url(@comment)
    assert_response :success
  end

  test "should get edit" do
    sign_in_as(users(:one))
    get edit_comment_url(@comment)
    assert_response :success
  end

  test "non-admin cannot edit ship comment" do
    non_admin = users(:two)
    sign_in_as(non_admin)

    ship_comment = comments(:ship_one)
    patch comment_url(ship_comment), params: { comment: { message: "hacked" } }

    assert_redirected_to root_url
    assert_match /not permitted/, flash[:alert]
    ship_comment.reload
    assert_not_equal "hacked", ship_comment.message
  end

  test "admin can edit ship comment" do
    admin = users(:admin)
    admin.update!(role: :admin)
    sign_in_as(admin)

    ship_comment = comments(:ship_one)
    patch comment_url(ship_comment), params: { comment: { message: "updated" } }

    assert_redirected_to comment_url(ship_comment)
    ship_comment.reload
    assert_equal "updated", ship_comment.message
  end

  test "should update comment" do
    sign_in_as(users(:one))
    patch comment_url(@comment), params: { comment: { message: "changed" } }
    assert_redirected_to comment_url(@comment)
  end

  test "should destroy comment" do
    sign_in_as(users(:one))
    assert_difference("Comment.count", -1) do
      delete comment_url(@comment)
    end

    assert_redirected_to comments_url
  end
end
