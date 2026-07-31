require "test_helper"

class UserLikeTest < ActiveSupport::TestCase
  test "valid with user and project" do
    ul = UserLike.new(user: users(:one), project: projects(:one))
    assert ul.valid?
  end

  test "validates user_id uniqueness scoped to project" do
    UserLike.create!(user: users(:one), project: projects(:one))
    dup = UserLike.new(user: users(:one), project: projects(:one))
    assert_not dup.valid?
  end

  test "allows same user with different projects" do
    UserLike.create!(user: users(:one), project: projects(:one))
    ul2 = UserLike.new(user: users(:one), project: projects(:two))
    assert ul2.valid?
  end

  test "belongs_to user" do
    ul = UserLike.new(user: users(:one))
    assert_equal users(:one), ul.user
  end

  test "belongs_to project" do
    ul = UserLike.new(project: projects(:one))
    assert_equal projects(:one), ul.project
  end
end
