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
      post comments_url, params: { comment: { message: "Not allowed", commentable_type: "Ship", commentable_id: ships(:one).id } }
    end

    assert_redirected_to root_url
    assert_match /Only admins/, flash[:alert]
  end

  test "admin can create ship comment" do
    admin = users(:admin)
    admin.update!(role: :admin)
    sign_in_as(admin)

    assert_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Admin comment", commentable_type: "Ship", commentable_id: ships(:one).id } }
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

    assert_response :see_other
  end

  # Order comment tests

  test "should create order comment via order_id param" do
    sign_in_as(users(:one))

    assert_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Order note" }, order_id: orders(:one).id }
    end

    assert_redirected_to root_url
    assert_match /Comment created/, flash[:notice]

    comment = Comment.order(created_at: :desc).first
    assert_equal "Order", comment.commentable_type
    assert_equal orders(:one).id, comment.commentable_id
    assert_equal users(:one), comment.user
  end

  test "should create order comment via explicit polymorphic params" do
    sign_in_as(users(:one))

    assert_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Polymorphic order comment", commentable_type: "Order", commentable_id: orders(:one).id } }
    end

    assert_redirected_to root_url
    comment = Comment.order(created_at: :desc).first
    assert_equal "Order", comment.commentable_type
    assert_equal orders(:one).id, comment.commentable_id
  end

  test "non-admin can create order comment" do
    sign_in_as(users(:two))

    assert_difference("Comment.count") do
      post comments_url, params: { comment: { message: "Allowed" }, order_id: orders(:one).id }
    end

    assert_redirected_to root_url
    assert_match /Comment created/, flash[:notice]
  end

  test "create order comment with blank message fails" do
    sign_in_as(users(:one))

    assert_no_difference("Comment.count") do
      post comments_url, params: { comment: { message: "" }, order_id: orders(:one).id }
    end

    assert_response :unprocessable_entity
  end

  test "order owner can edit their order comment" do
    sign_in_as(users(:one))

    order_comment = comments(:order_one)
    patch comment_url(order_comment), params: { comment: { message: "updated" } }

    assert_redirected_to comment_url(order_comment)
    order_comment.reload
    assert_equal "updated", order_comment.message
  end

  test "non-owner cannot edit order comment" do
    sign_in_as(users(:two))

    order_comment = comments(:order_one)
    patch comment_url(order_comment), params: { comment: { message: "hacked" } }

    assert_redirected_to root_url
    assert_match /not permitted/, flash[:alert]
    order_comment.reload
    assert_not_equal "hacked", order_comment.message
  end

  test "admin can edit any order comment" do
    admin = users(:admin)
    admin.update!(role: :admin)
    sign_in_as(admin)

    order_comment = comments(:order_one)
    patch comment_url(order_comment), params: { comment: { message: "admin updated" } }

    assert_redirected_to comment_url(order_comment)
    order_comment.reload
    assert_equal "admin updated", order_comment.message
  end

  test "destroy order comment redirects to comments path" do
    sign_in_as(users(:one))

    order_comment = comments(:order_one)
    assert_difference("Comment.count", -1) do
      delete comment_url(order_comment)
    end

    assert_redirected_to comments_url
  end

  test "unauthenticated user cannot create order comment" do
    assert_no_difference("Comment.count") do
      post comments_url, params: { comment: { message: "sneaky" }, order_id: orders(:one).id }
    end

    assert_response :unprocessable_entity
  end
end
