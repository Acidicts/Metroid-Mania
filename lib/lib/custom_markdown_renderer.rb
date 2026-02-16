# frozen_string_literal: true

require "redcarpet"
require "sanitize"

# Custom renderer that extends Redcarpet's HTML renderer
class CustomMarkdownRenderer < Redcarpet::Render::HTML
  # Example: Add a CSS class to all paragraphs
  def paragraph(text)
    "<p class='markdown-paragraph'>#{text}</p>"
  end

  # Example: Add target="_blank" to all links
  def link(link, title, content)
    title_attr = title ? " title='#{ERB::Util.html_escape(title)}'" : ""
    "<a href='#{ERB::Util.html_escape(link)}'#{title_attr} target='_blank' rel='noopener'>#{content}</a>"
  end

  # Render GitHub-style task list items: "- [x] ..." and "- [ ] ...".
  # We output a span with a checkbox glyph so Sanitize::RELAXED won't strip it.
  def list_item(text, list_type)
    # Normalize possible surrounding <p> tags Redcarpet may produce
    inner = text.to_s.gsub(/\A\s*<p>\s*/m, "").gsub(/\s*<\/p>\s*\z/m, "")

    if inner =~ /\A\s*\[([ xX])\]\s*(.*)/m
      checked = Regexp.last_match(1).strip.downcase == "x"
      content = Regexp.last_match(2)
      state_class = checked ? "task-list-item--checked" : "task-list-item--unchecked"

      # Data-URI SVGs (percent-encoded) for pixel-art checkboxes.
      unchecked_svg = "data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' shape-rendering='crispEdges'%3E%3Crect x='0' y='0' width='16' height='16' fill='%23ffffff'/%3E%3Crect x='1' y='1' width='14' height='14' fill='none' stroke='%230d2b45' stroke-width='1'/%3E%3C/svg%3E"
      checked_svg = "data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' shape-rendering='crispEdges'%3E%3Crect x='0' y='0' width='16' height='16' fill='%23ffd4a3'/%3E%3Crect x='1' y='1' width='14' height='14' fill='none' stroke='%230d2b45' stroke-width='1'/%3E%3Crect x='4' y='8' width='2' height='2' fill='%230d2b45'/%3E%3Crect x='6' y='10' width='2' height='2' fill='%230d2b45'/%3E%3Crect x='8' y='6' width='2' height='2' fill='%230d2b45'/%3E%3Crect x='10' y='4' width='2' height='2' fill='%230d2b45'/%3E%3C/svg%3E"

      img_src = checked ? checked_svg : unchecked_svg
      glyph = checked ? "&#x2611;" : "&#x2610;"  # textual fallback
      sr = checked ? " (checked)" : " (not checked)"

      "<li class='task-list-item #{state_class}'>" +
        "<span class='task-list-item-checkbox' aria-hidden='true'>" +
          "<img class='task-list-item-pixel' src='#{img_src}' alt=''>" +
          "<span class='task-list-item-fallback'>#{glyph}</span>" +
        "</span> " +
        "<span class='task-list-item-label'>#{content}<span class='sr-only'>#{sr}</span></span>" +
      "</li>"
    else
      "<li>#{text}</li>"
    end
  end
end

# Helper method to convert Markdown to safe HTML
def markdown_to_html(markdown_text)
  return "" if markdown_text.nil? || markdown_text.strip.empty?

  renderer = CustomMarkdownRenderer.new(
    filter_html: true, # Prevent raw HTML injection
    hard_wrap: true
  )

  markdown = Redcarpet::Markdown.new(
    renderer,
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    underline: true
  )

  # Convert and sanitize output to prevent XSS
  Sanitize.fragment(
    markdown.render(markdown_text),
    Sanitize::Config::RELAXED
  )
end
