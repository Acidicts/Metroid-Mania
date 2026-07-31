require "test_helper"

class AssetsProjectTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    ap = AssetsProject.new(title: "Game Art", description: "Assets for game", media_type: "sprite", user: users(:one))
    assert ap.valid?
  end

  test "validates title presence" do
    ap = AssetsProject.new(title: nil, description: "Test", media_type: "sprite", user: users(:one))
    assert_not ap.valid?
    assert_includes ap.errors[:title], "can't be blank"
  end

  test "validates description presence" do
    ap = AssetsProject.new(title: "Test", description: nil, media_type: "sprite", user: users(:one))
    assert_not ap.valid?
    assert_includes ap.errors[:description], "can't be blank"
  end

  test "validates media_type presence" do
    ap = AssetsProject.new(title: "Test", description: "Desc", media_type: nil, user: users(:one))
    assert_not ap.valid?
    assert_includes ap.errors[:media_type], "can't be blank"
  end

  test "validates image_url format" do
    ap = AssetsProject.new(image_url: "not-a-url")
    assert_not ap.valid?
    assert ap.errors[:image_url].any?
  end

  test "allows blank image_url" do
    ap = assets_projects(:one)
    ap.update!(image_url: nil)
    assert ap.valid?
  end

  test "image_url? returns true when present" do
    ap = AssetsProject.new(image_url: "https://example.com/img.png")
    assert_predicate ap, :image_url?
  end

  test "image_url? returns false when blank" do
    ap = AssetsProject.new(image_url: nil)
    assert_not ap.image_url?
  end

  test "hackatime_ids returns parsed array" do
    ap = AssetsProject.new
    ap.write_attribute(:hackatime_ids, [ "Alpha", "Beta" ].to_yaml)
    assert_equal [ "Alpha", "Beta" ], ap.hackatime_ids
  end

  test "hackatime_ids returns empty array for blank" do
    ap = AssetsProject.new
    ap.write_attribute(:hackatime_ids, nil)
    assert_equal [], ap.hackatime_ids
  end

  test "hackatime_ids= stores YAML" do
    ap = AssetsProject.new
    ap.hackatime_ids = [ "X", "Y" ]
    raw = ap.read_attribute(:hackatime_ids)
    assert_equal [ "X", "Y" ], YAML.safe_load(raw)
  end

  test "github_repo_parts parses GitHub URL" do
    ap = AssetsProject.new(repository_url: "https://github.com/owner/repo")
    parts = ap.github_repo_parts
    assert_equal "owner", parts[:owner]
    assert_equal "repo", parts[:repo]
  end

  test "github_repo_parts returns nil for blank URL" do
    ap = AssetsProject.new(repository_url: nil)
    assert_nil ap.github_repo_parts
  end

  test "github_repo_parts returns nil for non-GitHub URL" do
    ap = AssetsProject.new(repository_url: "https://gitlab.com/owner/repo")
    assert_nil ap.github_repo_parts
  end

  test "belongs_to user" do
    ap = assets_projects(:one)
    assert_equal users(:one), ap.user
  end

  test "has_many assets_items" do
    ap = assets_projects(:one)
    item = ap.assets_items.create!(title: "Test", description: "Desc", media_type: "sprite", user: users(:one))
    assert_includes ap.assets_items, item
  end
end
