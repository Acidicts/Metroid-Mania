require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "valid with message and user" do
    c = Comment.new(message: "Hello", user: users(:one))
    assert c.valid?
  end

  test "validates message presence" do
    c = Comment.new(message: nil, user: users(:one))
    assert_not c.valid?
    assert_includes c.errors[:message], "can't be blank"
  end

  test "order comment belongs to order" do
    o = orders(:one)
    c = Comment.new(message: "test", user: users(:one), commentable: o)
    assert_equal o, c.commentable
  end

  test "owner can edit" do
    user = users(:one)
    c = Comment.new(user: user, message: "test")
    assert c.editable_by?(user)
  end

  test "non-owner cannot edit" do
    c = Comment.new(user: users(:one), message: "test")
    assert_not c.editable_by?(users(:two))
  end

  test "admin can edit" do
    c = Comment.new(user: users(:one), message: "test")
    assert c.editable_by?(users(:admin))
  end

  test "nil user cannot edit" do
    c = Comment.new(user: users(:one), message: "test")
    assert_not c.editable_by?(nil)
  end

  test "editable_by? returns false for Ship commentable by non-admin" do
    p = projects(:one)
    ship = p.ships.create!(user: p.user, devlogged_seconds: 3600, shipped_at: Time.current)
    c = Comment.new(user: users(:one), message: "test", commentable: ship)
    assert_not c.editable_by?(users(:one))
  end

  test "editable_by? returns true for Ship commentable by admin" do
    p = projects(:one)
    ship = p.ships.create!(user: p.user, devlogged_seconds: 3600, shipped_at: Time.current)
    c = Comment.new(user: users(:one), message: "test", commentable: ship)
    assert c.editable_by?(users(:admin))
  end

  test "system? returns true when system flag is set" do
    c = Comment.new(system: true)
    assert_predicate c, :system?
  end

  test "system? returns false by default" do
    c = Comment.new
    assert_not c.system?
  end

  test "polymorphic commentable works with Devlog" do
    d = devlogs(:one)
    c = Comment.new(message: "Nice work", user: users(:one), commentable: d)
    assert c.valid?
    assert_equal d, c.commentable
  end
end
