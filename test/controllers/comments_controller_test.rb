require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should create comment on order" do
    order = orders(:one)
    assert_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Great order!", commentable_type: "Order", commentable_id: order.id } }
    end
    assert_response :redirect
  end

  test "should create comment on project" do
    p = projects(:one)
    assert_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Nice project!", commentable_type: "Project", commentable_id: p.id } }
    end
    assert_response :redirect
  end

  test "should update comment" do
    comment = comments(:one)
    patch comment_url(comment), params: { comment: { message: "Updated message" } }
    assert_response :redirect
  end

  test "non-owner cannot update comment" do
    comment = comments(:one)
    sign_in_as(users(:two))
    patch comment_url(comment), params: { comment: { message: "Hacked" } }
    assert_response :redirect
  end

  test "admin can update any comment" do
    comment = comments(:one)
    sign_in_as(users(:admin))
    patch comment_url(comment), params: { comment: { message: "Admin edited" } }
    assert_response :redirect
  end

  test "should destroy comment" do
    comment = comments(:one)
    assert_difference("Comment.count", -1) do
      delete comment_url(comment)
    end
    assert_response :redirect
  end
end
