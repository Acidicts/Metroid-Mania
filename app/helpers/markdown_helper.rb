# frozen_string_literal: true

# Helper to convert Markdown to safe HTML for views
# Loads the CustomMarkdownRenderer from lib/ and exposes `markdown_to_html` to templates.
require_dependency Rails.root.join('lib/lib/custom_markdown_renderer').to_s

module MarkdownHelper
  def markdown_to_html(markdown_text)
    return ''.html_safe if markdown_text.nil? || markdown_text.to_s.strip.empty?

    renderer = CustomMarkdownRenderer.new(
      filter_html: true,
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

    Sanitize.fragment(
      markdown.render(markdown_text.to_s),
      Sanitize::Config::RELAXED
    ).html_safe
  end

  # Fetch raw Markdown from GitHub (supports both github.com/blob/... and raw.githubusercontent.com)
  # - If `input` is a URL pointing at GitHub, it will attempt to fetch the raw file and render it.
  # - If `input` looks like plain Markdown, it renders it directly.
  # Returns an HTML-safe string.
  def github_markdown_to_html(input)
    return ''.html_safe if input.nil? || input.to_s.strip.empty?

    str = input.to_s.strip

    if looks_like_github_url?(str)
      raw_md = fetch_github_raw(str)
      return ''.html_safe if raw_md.nil? || raw_md.empty?
      return markdown_to_html(raw_md)
    end

    # Not a GitHub URL — treat as raw Markdown
    markdown_to_html(str)
  end

  private

  def looks_like_github_url?(str)
    uri = URI.parse(str) rescue nil
    return false unless uri && uri.host
    host = uri.host.downcase
    host.include?('github.com') || host.include?('raw.githubusercontent.com')
  end

  def fetch_github_raw(url)
    uri = URI.parse(url) rescue nil
    return nil unless uri

    # Only allow GitHub hosts to avoid SSRF
    allowed_hosts = %w[github.com raw.githubusercontent.com]
    return nil unless allowed_hosts.any? { |h| uri.host&.include?(h) }

    # Convert github.com blob URL -> raw.githubusercontent.com URL
    if uri.host.include?('github.com')
      # Example: https://github.com/owner/repo/blob/branch/path/to/README.md
      # -> https://raw.githubusercontent.com/owner/repo/branch/path/to/README.md
      parts = uri.path.split('/')
      blob_index = parts.index('blob')
      if blob_index && parts.size > blob_index + 2
        owner = parts[1]
        repo = parts[2]
        branch = parts[blob_index + 1]
        path = parts[(blob_index + 2)..-1].join('/')
        uri = URI.parse("https://raw.githubusercontent.com/#{owner}/#{repo}/#{branch}/#{path}")
      else
        # If URL points to repo root or doesn't contain blob, try common README locations on raw.githubusercontent
        owner, repo = parts[1], parts[2]
        if owner && repo
          # prefer main then master
          candidates = ["main", "master"]
          candidates.each do |branch|
            try_uri = URI.parse("https://raw.githubusercontent.com/#{owner}/#{repo}/#{branch}/README.md")
            body = fetch_uri_body(try_uri)
            return body if body && !body.empty?
          end
        end
        return nil
      end
    end

    fetch_uri_body(uri)
  end

  def fetch_uri_body(uri)
    Rails.cache.fetch("github_raw:#{uri}", expires_in: 10.minutes) do
      begin
        http = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 5)
        req = Net::HTTP::Get.new(uri)
        req['User-Agent'] = "Metroid-Mania/#{Rails.env} (fetch_github_raw)"
        res = http.request(req)
        if res.is_a?(Net::HTTPSuccess)
          res.body
        else
          nil
        end
      rescue StandardError => e
        Rails.logger.warn("fetch_github_raw failed for #{uri}: #{e.message}")
        nil
      end
    end
  end
end
