module ApplicationHelper
  def format_credits(amount)
    "#{amount.to_i} Units"
  end

  def format_duration(seconds, include_days: false)
    # ie: 2h 3m 4s
    # ie. 37h 15m (if include_days is false)
    # ie. 1d 13h 15m (if include_days is true)
    return "0s" if seconds.nil? || seconds <= 0

    days = seconds / 86400
    hours = include_days ? (seconds % 86400) / 3600 : seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    parts = []
    parts << "#{days}d" if include_days && days > 0
    parts << "#{hours}h" if hours > 0 || parts.any?
    parts << "#{minutes}m" if minutes > 0 || parts.any?
    parts << "#{secs}s" if secs > 0

    parts.join(" ")
  end

  # Check whether a logical asset exists in the current asset configuration.
  # Works with Sprockets (development) and Propshaft (production), with fallbacks.
  def asset_exists?(logical_path)
    # 1) Check local source file (works in dev & for simple deployments)
    return true if Rails.root.join("app", "assets", "stylesheets", logical_path).exist?

    # 2) Sprockets (development) - check the runtime environment
    if defined?(Rails.application.assets) && Rails.application.assets.respond_to?(:find_asset)
      return Rails.application.assets.find_asset(logical_path).present?
    end

    # 3) Propshaft manifest (produced to public/assets/manifest.json)
    manifest_path = Rails.root.join("public", "assets", "manifest.json")
    if manifest_path.exist?
      begin
        manifest = JSON.parse(manifest_path.read)
        return manifest.key?(logical_path)
      rescue => e
        Rails.logger.debug "asset_exists? manifest parse failed: #{e.message}"
      end
    end

    # 4) Fallback: check public/assets for files matching the logical name
    assets_dir = Rails.root.join("public", "assets")
    if assets_dir.exist?
      basename = File.basename(logical_path, File.extname(logical_path))
      return Dir.glob(assets_dir.join("#{basename}*")) .any?
    end

    false
  end

  # Render a controller-specific stylesheet tag when the matching CSS asset exists.
  def controller_stylesheet_link_tag
    logical = "#{controller_name}.css"
    if asset_exists?(logical)
      stylesheet_link_tag controller_name, "data-turbo-track": "reload"
    end
  end
end
