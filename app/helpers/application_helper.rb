module ApplicationHelper
  # convert a duration in seconds to a compact human string like "3h 12m".
  def human_duration(seconds)
    return "0h" if seconds.nil? || seconds.to_i <= 0
    total = seconds.to_i
    hrs = total / 3600
    mins = (total % 3600) / 60
    str = "#{hrs}h"
    str += " #{mins}m" if mins > 0
    str
  end
  def format_credits(amount)
    "#{amount.to_f.floor} #{credit_label}"
  end

  def order_by_public_id(public_id)
    Order.find_by(public_id: public_id)
  end

  def order_public_id_by_id(id)
    Order.find_by(id: id)&.public_id
  end

  def credits_total(project)
    project.ships.sum(:credits_awarded).to_f.floor
  end

  def is_flagged_for_fraud(user)
    user.flagged_for_fraud?
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
    parts << "#{days.floor}d" if include_days && days > 0
    parts << "#{hours.floor}h" if hours > 0 || parts.any?
    parts << "#{minutes.floor}m" if minutes > 0 || parts.any?
    parts << "#{secs.floor}s" if secs > 0

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
    # 1) Look for a source file anywhere under app/assets.  The original
    #    implementation only checked the top-level directory, which meant images
    #    kept inside `app/assets/images` were never found in development.  By
    #    searching recursively we can avoid precompiling just to satisfy the
    #    `asset_exists?` predicate.
    patterns = [
      Rails.root.join("app", "assets", "**", logical_path).to_s,
      # some gems (e.g. stimulus-rails) put assets under `app/javascript`
      Rails.root.join("app", "javascript", "**", logical_path).to_s
    ]
    return true if patterns.any? { |pat| Dir.glob(pat).any? }

    # 2) If a runtime asset environment is present (Sprockets in dev or a
    #    Propshaft assembly), ask it.  Propshaft::Assembly doesn't implement
    #    `find_asset`, so the check guards against that.  When an asset is missing
    #    Propshaft will raise, so rescue and fall through.
    if defined?(Rails.application.assets) &&
       Rails.application.assets.respond_to?(:find_asset)
      begin
        return Rails.application.assets.find_asset(logical_path).present?
      rescue Propshaft::MissingAssetError, Sprockets::FileNotFound
        # known failures – just continue to the next check
      end
    end

    # 3) Look in the precompiled manifest (Rails < 8 used manifest.json, newer
    #    versions name it `manifest-<digest>.json` or even `.js`).  We'll check
    #    for any file containing the basename to be tolerant of whatever naming
    #    scheme the compiler chose.
    assets_dir = Rails.root.join("public", "assets")
    if assets_dir.exist?
      basename = File.basename(logical_path, File.extname(logical_path))
      return Dir.glob(assets_dir.join("#{basename}*")).any?
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

  # Return an asset URL only if the given logical path actually exists.
  # We call `asset_exists?` first (which is now more forgiving) and then
  # attempt the normal helper; Propshaft/Sprockets will raise when the file
  # isn't in the load path, so rescue and return nil in that case.
  def asset_url_safe(logical_path)
    return unless asset_exists?(logical_path)
    begin
      asset_url(logical_path)
    rescue Propshaft::MissingAssetError, Sprockets::FileNotFound
      nil
    end
  end

  def get_all_credits(project)
    total = 0
    project.ships.each do |ship|
      total += ship.charm_notches.count
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
    if url =~ /\Ahttps?:\/\// || url =~ /\A\//
      url
    else
      "#" # Or a safe fallback URL
    end
  end

  # Return the most appropriate URL for displaying a project's banner image.
  #
  # * If an ActiveStorage attachment exists, `url_for` is used so the generated
  #   link respects the current request (host/port/protocol) rather than the
  #   static `default_url_options`.  This is crucial for crawlers like Slack
  #   which follow the OG metadata; using the request ensures we don't hand
  #   them a `localhost` URL when the site is accessed via a real hostname.
  # * Otherwise, fall back to the legacy `project.image_url` accessor, and
  #   finally to a generic placeholder.
  def project_banner_url(project)
    if project.respond_to?(:image) && project.image.respond_to?(:attached?) && project.image.attached?
      # ActiveStorage blob URLs need to be absolute for external crawlers.
      # Prefer using the current request's host and protocol when available.
      if defined?(request) && request.present?
        Rails.application.routes.url_helpers.rails_blob_url(
          project.image,
          host: request.host_with_port,
          protocol: request.protocol
        )
      else
        # try default host first; local view context may still have a value even
        # when `request` is not available (e.g. during preview rendering).
        host = Rails.application.routes.default_url_options[:host]
        if host.present?
          Rails.application.routes.url_helpers.rails_blob_url(project.image, host: host)
        else
          # no host; fall back to path-only which is safe but might confuse
          # external crawlers. This branch is rarely hit in a controller/view
          # context because a host is usually set.
          Rails.application.routes.url_helpers.rails_blob_path(project.image, only_path: true)
        end
      end
    elsif project.respond_to?(:image_url) && project.image_url.present?
      project.image_url
    else
      "https://placehold.co/800x450"
    end
  end
end
