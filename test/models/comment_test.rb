require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    @order_comment = comments(:order_one)
  end

  test "valid comment" do
    comment = Comment.new(user: users(:one), message: "Hello", commentable: orders(:one))
    assert comment.valid?
  end

  test "message must be present" do
    comment = Comment.new(user: users(:one), commentable: orders(:one))
    assert_not comment.valid?
    assert_includes comment.errors[:message], "can't be blank"
  end

  test "order comment belongs to an order" do
    assert_equal "Order", @order_comment.commentable_type
    assert_equal orders(:one).id, @order_comment.commentable_id
  end

  test "order comment's commentable is an Order instance" do
    assert_instance_of Order, @order_comment.commentable
  end

  test "owner can edit their order comment" do
    assert @order_comment.editable_by?(users(:one))
  end

  test "non-owner cannot edit order comment" do
    assert_not @order_comment.editable_by?(users(:two))
  end

  test "admin can edit any order comment" do
    admin = users(:admin)
    admin.update!(role: :admin)
    assert @order_comment.editable_by?(admin)
  end

  test "nil user cannot edit order comment" do
    assert_not @order_comment.editable_by?(nil)
  end
end
