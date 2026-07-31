require "test_helper"

class ProjectsHelperTest < ActionView::TestCase
  include ProjectsHelper

  test "safe_url returns nil for blank" do
    assert_nil safe_url("")
    assert_nil safe_url(nil)
  end

  test "safe_url returns path for path strings" do
    assert_equal "/foo/bar", safe_url("/foo/bar")
  end

  test "safe_url returns https URLs" do
    assert_equal "https://example.com", safe_url("https://example.com")
  end

  test "safe_url returns http URLs" do
    assert_equal "http://example.com", safe_url("http://example.com")
  end

  test "safe_url returns nil for invalid URIs" do
    assert_nil safe_url("not a url")
  end

  test "ensure_url_scheme adds https when missing" do
    assert_equal "https://example.com", ensure_url_scheme("example.com")
  end

  test "ensure_url_scheme preserves existing scheme" do
    assert_equal "https://example.com", ensure_url_scheme("https://example.com")
    assert_equal "http://example.com", ensure_url_scheme("http://example.com")
  end

  test "ensure_url_scheme returns nil for blank" do
    assert_nil ensure_url_scheme("")
    assert_nil ensure_url_scheme(nil)
  end
end
