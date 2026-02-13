# frozen_string_literal: true

require 'redcarpet'
require 'sanitize'

# Custom renderer that extends Redcarpet's HTML renderer
class CustomMarkdownRenderer < Redcarpet::Render::HTML
  # Example: Add a CSS class to all paragraphs
  def paragraph(text)
    "<p class='markdown-paragraph'>#{text}</p>"
  end

  # Example: Add target="_blank" to all links
  def link(link, title, content)
    title_attr = title ? " title='#{ERB::Util.html_escape(title)}'" : ''
    "<a href='#{ERB::Util.html_escape(link)}'#{title_attr} target='_blank' rel='noopener'>#{content}</a>"
  end
end

# Helper method to convert Markdown to safe HTML
def markdown_to_html(markdown_text)
  return '' if markdown_text.nil? || markdown_text.strip.empty?

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
