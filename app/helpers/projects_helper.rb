require "uri"

module ProjectsHelper
  # Return a URL string only if it parses as http, https, or a same-host path.
  # This is useful for ActiveStorage paths like `/rails/active_storage/blobs/...`.
  def safe_url(url)
    return nil if url.blank?
    return url if url =~ %r{\A/}
    uri = URI.parse(url)
    uri.to_s if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    nil
  end

  # Helper to link to external URLs only when they look safe. Adds noopener noreferrer.
  def external_link_to(url, text = nil, **opts)
    text ||= url
    safe = safe_url(url)
    if safe
      opts[:target] ||= "_blank"
      opts[:rel] = [ opts[:rel], "noopener noreferrer" ].compact.join(" ")
      link_to text, safe, **opts
    else
      text
    end
  end

  def ensure_url_scheme(url)
    return nil if url.blank?
    url =~ /\Ahttps?:\/\//i ? url : "https://#{url}"
  end
end
