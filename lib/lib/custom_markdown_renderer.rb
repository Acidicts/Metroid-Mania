# frozen_string_literal: true

require "redcarpet"
require "sanitize"

module Lib
  # Custom renderer that extends Redcarpet's HTML renderer
  class CustomMarkdownRenderer < Redcarpet::Render::HTML
    # Example: Add a CSS class to all paragraphs
    def paragraph(text)
      "<p class='markdown-paragraph'>#{text}</p>"
    end

    # Example: Add target="_blank" to all links
    def link(link, title, content)
      title_attr = title ? " title='#{ERB::Util.html_escape(title)}'" : ""
      "<a href='#{ERB::Util.html_escape(link)}'#{title_attr} target='_blank' rel='noopener noreferrer'>#{content}</a>"
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

        # Use SVG asset files for pixel-art checkboxes (prefer asset pipeline; fall back to plain asset paths).
        if defined?(ActionController::Base) && ActionController::Base.respond_to?(:helpers)
          unchecked_svg = ERB::Util.html_escape(ActionController::Base.helpers.asset_path("empty_checkbox.svg"))
          checked_svg   = ERB::Util.html_escape(ActionController::Base.helpers.asset_path("ticked_checkbox.svg"))
        else
          # Fallback (development / precompiled asset path)
          unchecked_svg = "/assets/empty_checkbox.svg"
          checked_svg   = "/assets/ticked_checkbox.svg"
        end

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
end

CustomMarkdownRenderer = Lib::CustomMarkdownRenderer unless defined?(CustomMarkdownRenderer)

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
  sanitize_config = Sanitize::Config::RELAXED.dup
  sanitize_config[:attributes] = (sanitize_config[:attributes] || {}).dup
  sanitize_config[:attributes]["a"] = (sanitize_config[:attributes]["a"] || []) | [ "target", "rel" ]

  Sanitize.fragment(
    markdown.render(markdown_text),
    sanitize_config
  )
end
