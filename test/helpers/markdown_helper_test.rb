require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  include MarkdownHelper

  test "markdown_to_html renders basic markdown" do
    result = markdown_to_html("**bold**")
    assert_match /bold/, result
  end

  test "markdown_to_html returns safe html for nil" do
    result = markdown_to_html(nil)
    assert_equal "".html_safe, result
  end

  test "markdown_to_html returns safe html for empty string" do
    result = markdown_to_html("")
    assert_equal "".html_safe, result
  end

  test "markdown_to_html renders code blocks" do
    result = markdown_to_html("```ruby\nputs 'hello'\n```")
    assert_match /puts/, result
  end

  test "markdown_to_html renders links" do
    result = markdown_to_html("[link](https://example.com)")
    assert_match /example\.com/, result
  end

  test "looks_like_github_url? detects github.com URLs" do
    assert looks_like_github_url?("https://github.com/owner/repo")
    assert looks_like_github_url?("https://raw.githubusercontent.com/owner/repo/main/README.md")
    assert_not looks_like_github_url?("https://example.com/file.md")
  end

  test "github_markdown_to_html renders plain markdown" do
    result = github_markdown_to_html("**hello**")
    assert_match /hello/, result
  end

  test "github_markdown_to_html returns safe html for nil" do
    result = github_markdown_to_html(nil)
    assert_equal "".html_safe, result
  end
end
