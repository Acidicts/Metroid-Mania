require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "belongs_to project" do
    post = Post.new(project: projects(:one), user: users(:one))
    assert_equal projects(:one), post.project
  end

  test "belongs_to user" do
    post = Post.new(project: projects(:one), user: users(:one))
    assert_equal users(:one), post.user
  end

  test "valid with required associations" do
    post = Post.new(project: projects(:one), user: users(:one))
    assert post.valid?
  end
end
