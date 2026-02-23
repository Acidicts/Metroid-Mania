module ApplicationHelper
  def format_credits(amount)
    "#{amount.to_f.floor} #{credit_label}"
  end

  def order_by_public_id(public_id)
    Order.find_by(public_id: public_id)
  end

  def order_public_id_by_id(id)
    Order.find_by(id: id)&.public_id
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

  def calculate_total_charm_slots(user)
    hours = calculate_user_total_time(user) / 3600.0
    (hours / 5).floor + 1 # Every 12 hours = 1 charm slot
  end

  def calculate_user_total_time(user)
      Ship.joins(:project).where(projects: { user_id: user.id, deleted_at: nil }).sum(:devlogged_seconds).to_i
  end

  # Check whether a logical asset exists in the current asset configuration.
  # Works with Sprockets (development) and Propshaft (production), with fallbacks.
  def asset_exists?(logical_path)
    # 1) Look for a source file under app/assets (images, javascripts, stylesheets).
    #    This works in development and for simple deployments where assets aren't
    #    precompiled.  We check the generic `app/assets` tree because the logical
    #    path doesn't indicate the subfolder.
    return true if Rails.root.join("app", "assets", logical_path).exist?

    # 2) If a runtime asset environment is present (Sprockets in dev or a
    #    Propshaft environment), ask it.  Propshaft::Environment#find_asset will
    #    raise when the logical path is missing, so swallow that and return false.
    if defined?(Rails.application.assets) && Rails.application.assets.respond_to?(:find_asset)
      begin
        return Rails.application.assets.find_asset(logical_path).present?
      rescue Propshaft::MissingAssetError
        return false
      end
    end

    # 3) Inspect the Propshaft manifest produced by `rails assets:precompile`.
    manifest_path = Rails.root.join("public", "assets", "manifest.json")
    if manifest_path.exist?
      begin
        manifest = JSON.parse(manifest_path.read)
        return manifest.key?(logical_path)
      rescue => e
        Rails.logger.debug "asset_exists? manifest parse failed: #{e.message}"
      end
    end

    # 4) Last‑ditch: look for any file with a matching basename in public/assets.
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

  # Human-friendly label for site-specific credits (configured by ENV['CREDIT_NAME']).
  # Falls back to 'Credits' when not set.
  def credit_label
    ENV["CREDIT_NAME"].presence || "Credits"
  end

  # Calculate average credits per hour across all ships for a project
  def average_credits_per_hour(project)
    # Use memoization to avoid recalculating for the same project
    @avg_credits_cache ||= {}
    return @avg_credits_cache[project.id] if @avg_credits_cache.key?(project.id)

    ships = project.ships.to_a # Use the preloaded association
    return @avg_credits_cache[project.id] = 0 if ships.empty?

    total_credits = ships.sum { |s| s.credits_awarded.to_f }
    total_hours = ships.sum { |s| s.devlogged_seconds.to_f / 3600.0 }

    @avg_credits_cache[project.id] = total_hours > 0 ? (total_credits / total_hours).round(2) : 0
  end

  def user_total_ships(user)
    return 0 if user.nil?
    # Use cached value if available
    @user_ships_cache ||= {}
    @user_ships_cache[user.id] ||= begin
      Ship.joins(:project)
          .where(projects: { user_id: user.id, deleted_at: nil })
          .count
    end
  end

  # Calculate total credits across all ships for a user (exclude deleted projects) plus any admin offset.
  # Always rounded up to the nearest integer.
  def user_total_credits(user)
    return 0 if user.nil?
    raw = Ship.joins(:project).where(projects: { user_id: user.id, deleted_at: nil }).sum(:credits_awarded).to_f +
            (user.credit_offset || 0.0)
    raw.ceil
  end

  # Return available balance for a user: (total shipped credits + offset) minus amount spent.
  # Always rounded up to the nearest integer.
  def user_balance(user)
    return 0 if user.nil?
    (user_total_credits(user) - (user.amount_spent || 0.0)).ceil
  end

  # Calculate total ships for a project
  def total_ships(project)
    # Use the preloaded association instead of triggering a new query
    project.ships.size
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
