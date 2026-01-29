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

  def correct_credits(amount)
    return 0 if amount.nil?
    amount.ceil
  end

  def get_all_credits(project)
    total = 0
    project.ships.each do |ship|
      total += ship.credits_awarded.to_f
    end
    total
  end

  # Calculate average credits per hour across all ships for a project
  def average_credits_per_hour(project)
    return 0 if project.ships.empty?

    total_credits = 0
    total_hours = 0

    project.ships.each do |ship|
      total_credits += ship.credits_awarded.to_f
      total_hours += ship.devlogged_seconds.to_f / 3600.0 if ship.devlogged_seconds.present?
    end

    return 0 if total_hours == 0

    (total_credits / total_hours).round(2)
  end

  def user_total_ships(user)
    ships = 0
    for project in user.projects
      ships += total_ships(project)
    end
    ships
  end

  # Calculate total credits across all ships for a user
  def user_total_credits(user)
    return 0 if user.nil?
    # Use DB aggregation for efficiency and handle nil credits gracefully
    user.ships.sum(:credits_awarded).to_f
  end

  # Calculate total ships for a project
  def total_ships(project)
    project.ships.count
  end

  # app/helpers/application_helper.rb
  def safe_url(url)
    if url =~ /\Ahttps?:\/\//
      url
    else
      "#" # Or a safe fallback URL
    end
  end
end
