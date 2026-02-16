require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  include MarkdownHelper

  test "renders task list checkboxes for [x] and [ ]" do
    md = "- [x] Done\n- [ ] Not done"
    html = markdown_to_html(md)

    # should render the task-list structure and state classes
    assert_includes html, "task-list-item"
    assert_includes html, "task-list-item-checkbox"
    assert_includes html, "task-list-item--checked"
    assert_includes html, "task-list-item--unchecked"
    assert_includes html, "task-list-item-pixel"

    # ensure the labels are present
    assert_match /Done/, html
    assert_match /Not done/, html
  end
end
