require "test_helper"

class ProjectTagTest < ActiveSupport::TestCase
  test "valid with tag_string" do
    tag = ProjectTag.new(tag_string: "gamedev")
    assert tag.valid?
  end

  test "validates tag_string presence" do
    tag = ProjectTag.new(tag_string: nil)
    assert_not tag.valid?
    assert_includes tag.errors[:tag_string], "can't be blank"
  end

  test "validates tag_string uniqueness scoped to project" do
    project = projects(:one)
    ProjectTag.create!(tag_string: "unique-tag", project: project)
    dup = ProjectTag.new(tag_string: "unique-tag", project: project)
    assert_not dup.valid?
  end

  test "allows same tag_string for different projects" do
    p1 = projects(:one)
    p2 = projects(:two)
    ProjectTag.create!(tag_string: "shared-tag", project: p1)
    tag2 = ProjectTag.new(tag_string: "shared-tag", project: p2)
    assert tag2.valid?
  end

  test "alias_attribute tag maps to tag_string" do
    tag = ProjectTag.new(tag: "test-tag")
    assert_equal "test-tag", tag.tag_string
  end

  test "update_tag updates and saves" do
    tag = ProjectTag.create!(tag_string: "old")
    tag.update_tag("new")
    assert_equal "new", tag.reload.tag_string
  end

  test "belongs_to project optionally" do
    tag = ProjectTag.new(tag_string: "no-project")
    assert_nil tag.project
    tag.project = projects(:one)
    assert_equal projects(:one), tag.project
  end

  test "has_many tagged_projects" do
    tag = ProjectTag.create!(tag_string: "tagged")
    project = projects(:one)
    project.update!(project_tag: tag)
    assert_includes tag.tagged_projects, project
  end
end
