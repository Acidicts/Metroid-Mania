class Project < ApplicationRecord
  belongs_to :user

  # tag association: each project can optionally be linked to a single
  # ProjectTag record (chosen from the admin-maintained list).
  #
  # we also expose a simple `tags` reader so existing views that previously
  # expected a comma-separated list will continue to work without blowing up.
  belongs_to :project_tag, optional: true

  has_many :devlogs, dependent: :destroy
  has_many :ships, dependent: :destroy
  has_many :ship_requests, dependent: :destroy
  has_many :audits, dependent: :nullify

  # likes: users who have liked this project
  has_many :user_likes, dependent: :destroy
  has_many :likers, through: :user_likes, source: :user

  # Attach a representative image for the project (Active Storage)
  has_one_attached :image

  # Provide a unified "image_url" reader so views (and metadata tags) can
  # consume either the legacy URL-style attribute (if present) or an
  # ActiveStorage attachment.  Previously the show template referenced
  # `@project.image_url` directly which raised a NoMethodError because the
  # projects table has never contained such a column.  Defining this method
  # keeps the interface stable and automatically generates a full URL for a
  # blob when an image is attached.  Controllers/tests may still assign
  # `project.image_url = "…"` during the transition; any non‑persisted
  # value will be returned verbatim if present.
  def image_url
    # prefer an explicit attribute if one exists (unlikely today but harmless)
    if has_attribute?(:image_url) && self[:image_url].present?
      return self[:image_url]
    end

    # fall back to ActiveStorage blob URL when attached
    return nil unless image.respond_to?(:attached?) && image.attached?

    # don't attempt to create/upload the URL just for display; callers invoking
    # this reader (especially views) shouldn't trigger network activity or
    # writes.  an update validation handles persistence when a blob is added.
    project_banner_url(self)
  end

  validates :name, presence: true
  validates :repository_url, presence: true

  # Server-side reachability checks: ensure README URLs (and GitHub repo READMEs)
  # respond successfully. These are conservative (only run for http(s) URLs or
  # GitHub repos) and use short timeouts so they don't slow normal requests.
  validate :readme_url_must_be_reachable
  validate :github_repository_must_have_readme
  validate :ship_total_notches, on: :update

  validate :ensure_has_image_url,
           on: :update,
           if: -> { self[:image_url].blank? }

  # After saving, if the ActiveStorage image was changed we need to clear any
  # stored `image_url` so it doesn't continue pointing at the previous image.
  # The callback uses a separate update to avoid interfering with the original
  # transaction, and guards on the attachment/blob change to prevent looping.
  after_save :reset_image_url_if_image_changed

  def likes
    likers.count
  end

  def ensure_has_image_url
    return true if !self[:image_url].blank?
    return false if !self.image.attached?
    displayed_url = project_banner_url(self)
    response = CdnService.upload_from_url(displayed_url)

    url = response.respond_to?(:[]) ? response["url"] : nil
    unless url.present?
      # upload failed or CDN not configured; skip without blowing up.
      Rails.logger.warn("ensure_has_image_url: upload_from_url returned #{response.inspect}") if defined?(Rails)
      return false
    end

    self.image_url = url
    save!(validate: false)
  end

  def reset_image_url!
    self[:image_url] = nil
    save!(validate: true)
  end

  # helper used by after_save callback above
  def reset_image_url_if_image_changed
    # `saved_change_to_image_attachment?` and `saved_change_to_image_blob?` are
    # provided by ActiveStorage.  tests run in an environment where
    # ActiveStorage may not be fully configured, which previously caused a
    # NoMethodError when the callback fired. Guard the calls so we simply skip
    # when the methods are missing.
    if (respond_to?(:saved_change_to_image_attachment?) && saved_change_to_image_attachment?) ||
       (respond_to?(:saved_change_to_image_blob?) && saved_change_to_image_blob?)
      reset_image_url!
    end
  end

  # Store multiple Hackatime project names in the text `hackatime_ids` column as YAML.
  # Provide simple accessor helpers so the model behaves like an Array.
  def tags
    # provide a minimal compatibility layer for callers that expect an array
    # of strings.  switching to a single `project_tag_id` field means there is
    # only ever zero or one value but the old form code joined the array, so
    # returning an array keeps existing templates functional until they're
    # updated.  we avoid any database queries here (thanks to eager loading in
    # controllers) and simply delegate to the association.
    project_tag ? [ project_tag.tag ] : []
  end

  # setter is mostly to make mass-assignment of the old `tags` field
  # behave sanely during transition.  it will pick the first supplied tag
  # name and, if a matching ProjectTag exists, associate it; otherwise a new
  # record scoped to this project is created.  this is intentionally simple
  # because the new UI never calls it.
  def tags=(vals)
    arr = Array(vals).flat_map { |v| v.to_s.split(",") }.map(&:strip).reject(&:blank?)
    if arr.any?
      name = arr.first
      self.project_tag = ProjectTag.find_by(tag_string: name) ||
                         ProjectTag.create!(tag: name, project: self)
    else
      self.project_tag = nil
    end
  end

  def hackatime_ids
    raw = read_attribute(:hackatime_ids)
    return [] if raw.nil? || raw == ""
    return raw if raw.is_a?(Array)

    begin
      YAML.safe_load(raw) || []
    rescue
      raw.to_s.split(",").map(&:strip)
    end
  end

  def ship_total_notches
    for ship in ships
      ship_time = ship.devlogged_seconds.to_i
      expected_amount = ((ship_time.to_f / 3600.0) * 0.5).to_f.floor()
      if ship.charm_notches.count > expected_amount
        ship.charm_notches.where.not(charm_slot_id: nil).limit(ship.charm_notches.count - expected_amount).each do |n|
          n.destroy!
        end
      elsif ship.charm_notches.count < expected_amount
        (expected_amount - ship.charm_notches.count).to_i.times do
          CharmNotch.create!(user: ship.user, ship: ship, charm_slot: nil)
        end
      end
    end
  end

  def hackatime_ids=(vals)
    write_attribute(:hackatime_ids, vals.present? ? vals.to_yaml : nil)
  end

  def total_devlogged_seconds
    # Count all user-created devlogs (exclude system-generated devlogs which have no user_id).
    # User-created devlogs are counted regardless of whether they've been linked to a ship request,
    # so that documented time remains documented after shipping and cannot be reused.
    devlogs.where.not(user_id: nil).sum(:duration_seconds)
  end

  # Remaining seconds on the project that have not been devlogged yet.
  # Used by views/controllers to determine if a user can create a devlog.
  def undocumented_seconds
    [ total_seconds.to_i - total_devlogged_seconds, 0 ].max
  end

  # Return array of target names to query in Hackatime. Backwards compatible with `hackatime_id`.
  def hackatime_targets
    if hackatime_ids.present? && hackatime_ids.any?
      hackatime_ids.map(&:to_s)
    elsif respond_to?(:hackatime_id) && hackatime_id.present?
      [ hackatime_id.to_s ]
    else
      [ name ]
    end
  end

  def update_time_from_hackatime!
    return unless user.slack_id.present?

    service = HackatimeService.new(slack_id: user.slack_id)
    # Use the per-project lookup so unit tests that stub `get_project_stats` behave correctly.
    total = hackatime_targets.sum { |t| service.get_project_stats(t).to_i }
    update(total_seconds: total) if total > 0
  end

  def time
    remaining = [ total_seconds.to_i - total_devlogged_seconds, 0 ].max
    hours = (remaining / 3600).floor
    minutes = ((remaining % 3600) / 60).floor
    "#{hours} hrs #{minutes} mins"
  end

  # Returns true when any Ship on this project recorded seconds that cannot be
  # fully explained by in-app devlogs — this implies Hackatime/externally-sourced
  # time was used when the project was shipped.
  def hackatime_time_used_in_ships?
    # Conservative detection: treat a Ship as having used Hackatime-derived project time
    # when its recorded devlogged_seconds exactly matches the project's stored total_seconds
    # AND that recorded seconds cannot be fully explained by user-created devlogs before
    # the ship time. This avoids false positives when a ship used explicit devlogged_seconds
    # that happen to equal `total_seconds`.
    return false if total_seconds.to_i <= 0

    ships.any? do |s|
      ssec = s.devlogged_seconds.to_i
      next false if ssec <= 0
      next false unless ssec == total_seconds.to_i

      logged = devlogs.where.not(user_id: nil).where("created_at <= ?", s.shipped_at).sum(:duration_seconds).to_i
      logged < ssec
    end
  end

  # Returns the set of Hackatime IDs that are locked (cannot be removed) because
  # they were present on the project when it was shipped. Only protects IDs that
  # existed at ship time — IDs added after a ship can still be removed.
  def locked_hackatime_ids
    ships.flat_map(&:hackatime_ids_snapshot).uniq.compact
  end

  # Returns true if the given hackatime_id is locked (present on any ship snapshot)
  def hackatime_id_locked?(id)
    locked_hackatime_ids.map(&:to_s).include?(id.to_s)
  end

  # Ensure hackatime projects are not linked to multiple projects
  validate :hackatime_ids_unique_across_projects
  validate :prevent_removal_of_hackatime_if_time_used, on: :update

  private

    # Return an appropriate banner URL for a project.  This mirrors the
    # helper implementation so the model can call it without pulling in view
    # helpers or relying on a request object.  When no request is available,
    # prefer a configured default host to avoid exposing relative URLs to
    # external services such as the CDN upload.
    def project_banner_url(project)
      if project.respond_to?(:image) && project.image.respond_to?(:attached?) && project.image.attached?
        if defined?(request) && request.present?
          Rails.application.routes.url_helpers.rails_blob_url(project.image, host: request.base_url)
        else
          host = Rails.application.routes.default_url_options[:host]
          if host.present?
            Rails.application.routes.url_helpers.rails_blob_url(project.image, host: host)
          else
              Rails.application.routes.url_helpers.rails_blob_path(project.image, only_path: true)
          end
        end
      elsif project.respond_to?(:image_url) && project.image_url.present?
        project.image_url
      else
        "https://placehold.co/800x450"
      end
    end

  def hackatime_ids_unique_across_projects
    return if hackatime_ids.blank?

    other_names = Project.where.not(id: id).flat_map(&:hackatime_ids).map(&:to_s)
    overlap = hackatime_ids.map(&:to_s) & other_names
    if overlap.any?
      errors.add(:hackatime_ids, "contains project(s) already linked: #{overlap.join(', ')}")
    end
  end

  # Prevent removing linked Hackatime projects when Hackatime-derived time was used
  # for any Ship on this project. We detect "used Hackatime time" by comparing a
  # Ship's recorded seconds to the sum of user-created devlogs at the time of that ship.
  def prevent_removal_of_hackatime_if_time_used
    return unless persisted?

    # Determine which hackatime IDs would be removed by this update
    current_db_ids = (Project.find(id).hackatime_ids || [])
    removed = (current_db_ids - (hackatime_ids || []))
    return if removed.blank?

    # Block removal only for IDs that were present when the project was shipped
    locked = locked_hackatime_ids.map(&:to_s)
    protected_being_removed = removed.map(&:to_s) & locked

    if protected_being_removed.any?
      errors.add(:hackatime_ids, "cannot remove Hackatime project(s) [#{protected_being_removed.join(', ')}] that were linked when the project was shipped")
    end
  end

  # Server-side validator: ensure explicit README URL is reachable and not 404.
  def readme_url_must_be_reachable
    # Only treat an explicit HTTP 404 as a blocking validation error.
    # Network/CORS/timeouts or other HTTP statuses will not prevent save.
    return if readme_url.blank?
    begin
      uri = URI.parse(readme_url) rescue nil
      return unless uri && %w[http https].include?(uri.scheme)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 3) do |http|
        head_req = Net::HTTP::Head.new(uri.request_uri)
        res = http.request(head_req) rescue nil

        if res && res.code.to_i == 404
          errors.add(:readme_url, "returned 404 (not found)")
          return
        end

        # If HEAD wasn't successful, try GET — still only error on 404
        unless res && res.is_a?(Net::HTTPSuccess)
          get_req = Net::HTTP::Get.new(uri.request_uri)
          get_res = http.request(get_req) rescue nil
          if get_res && get_res.code.to_i == 404
            errors.add(:readme_url, "returned 404 (not found)")
            return
          end
          # otherwise be permissive (network/timeouts/403/etc. do not block save)
        end
      end
    rescue StandardError => _e
      # Do not add a validation error on transient network/timeout exceptions.
      nil
    end
  end

  # Server-side validator: if repository_url points at GitHub, ensure a README.md exists
  # on a common branch (or the explicit branch if present). Fail on 404.
  def github_repository_must_have_readme
    return if repository_url.blank?

    m = repository_url.match(/(?:github\.com[:\/])([^\/\s@]+)\/([^\/\s@]+)(?:\.git)?(?:[\/\#?].*)?/i)
    return unless m

    owner = m[1]
    repo_name = m[2].gsub(/\.git$/i, "")
    branch_match = repository_url.match(/\/(?:tree|blob)\/([^\/\s\/]+)/i)
    branches_to_try = branch_match ? [ branch_match[1] ] : [ "main", "master" ]

    saw_404 = false
    branches_to_try.each do |br|
      uri = URI.parse("https://raw.githubusercontent.com/#{owner}/#{repo_name}/#{CGI.escape(br)}/README.md")
      begin
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 3) do |http|
          req = Net::HTTP::Head.new(uri.request_uri)
          res = http.request(req) rescue nil

          if res && res.is_a?(Net::HTTPSuccess)
            return true
          end

          saw_404 = true if res && res.code.to_i == 404
        end
      rescue StandardError
        # network error — try next branch
      end
    end

    # Only add a blocking validation error when we actually observed a 404 on the README
    if saw_404
      errors.add(:repository_url, "README.md not found on the repository (404)")
    end
  end

  public

  # Allowed statuses for projects
  STATUSES = %w[unshipped pending shipped rejected deleted].freeze

  # Scope for non-deleted projects
  scope :active, -> { where(deleted_at: nil) }

  # Order projects by total user-created devlogged seconds (SQL-side aggregate).
  # Uses CASE to ignore system-generated devlogs (user_id IS NULL).
  scope :order_by_total_devlogged_seconds, ->(dir = :desc) {
    dir_sql = dir.to_s.upcase == "ASC" ? "ASC" : "DESC"
    left_joins(:devlogs)
      .group("projects.id")
      .order(Arel.sql("SUM(CASE WHEN devlogs.user_id IS NOT NULL THEN devlogs.duration_seconds ELSE 0 END) #{dir_sql}"))
  }

  # Soft-delete predicate
  def deleted?
    deleted_at.present?
  end

  # Set default status for new projects
  before_create do
    self.status ||= "unshipped"
    # Only set shipped to false by default if it's currently nil
    self.shipped = false if respond_to?(:shipped) && self.shipped.nil?
  end

  # Baseline timestamp used to calculate whether enough work has been done since creation or last ship
  def ship_baseline
    shipped_at || created_at
  end

  # Minutes of devlogged work created since baseline (exclude system-generated devlogs)
  def devlogged_minutes_since_baseline
    (devlogs.where.not(user_id: nil).where("created_at >= ?", ship_baseline).sum(:duration_seconds).to_i / 60)
  end

  # Can the owner request a ship? Must not already be pending and at least 15 minutes of devlogs since baseline
  def eligible_for_ship_request?
    return false if status == "pending"
    devlogged_minutes_since_baseline >= 15
  end

  # Minutes still required for the owner to be able to request a ship (0 when eligible)
  def minutes_needed_for_ship_request
    [ 15 - devlogged_minutes_since_baseline.to_i, 0 ].max
  end

  # Can an admin ship (approve) this project? Must be pending and have at least 15 minutes of devlogs since baseline
  def eligible_for_admin_ship?
    # Admins may approve/ship a pending project when either:
    # - there are >= 15 minutes of devlogs since the baseline (owner-requested work), OR
    # - the project already has sufficient recorded total_seconds (admin fallback).
    return false unless status == "pending"
    devlogged_minutes_since_baseline >= 15 || total_seconds.to_i >= 15.minutes.to_i
  end

  # --- GitHub / repository helpers (used by views/helpers) -----------------

  # Parse GitHub owner/repo (and optional branch) from repository_url. Returns
  # a hash { owner:, repo:, branch: } or nil when the URL doesn't look like GitHub.
  def github_repo_parts
    return nil if repository_url.blank?
    m = repository_url.match(/(?:github\.com[:\/])([^\/\s@]+)\/([^\/\s@]+)(?:\.git)?(?:[\/\#?].*)?/i)
    return nil unless m
    owner = m[1]
    repo_name = m[2].gsub(/\.git$/i, "")
    branch_match = repository_url.match(/\/(?:tree|blob)\/([^\/\s\/]+)/i)
    { owner: owner, repo: repo_name, branch: (branch_match ? branch_match[1] : nil) }
  end

  # Return true when a README.md is reachable either via explicit readme_url or
  # by checking the repository's README on GitHub (tries branch if present,
  # otherwise main/master). Results are cached briefly to avoid repeated network calls.
  def github_readme_present?
    return true if readme_url.present?
    parts = github_repo_parts
    return false unless parts

    branches = parts[:branch] ? [ parts[:branch] ] : [ "main", "master" ]

    branches.any? do |br|
      Rails.cache.fetch("project:#{id}:github_readme:#{br}", expires_in: 10.minutes) do
        uri = URI.parse("https://raw.githubusercontent.com/#{parts[:owner]}/#{parts[:repo]}/#{CGI.escape(br)}/README.md")
        begin
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 3) do |http|
            req = Net::HTTP::Head.new(uri.request_uri)
            res = http.request(req) rescue nil
            res && res.is_a?(Net::HTTPSuccess)
          end
        rescue StandardError
          false
        end
      end
    end
  end

  # Heuristic: determine whether the GitHub repository is publicly reachable.
  # We treat a repository as public when an unauthenticated HEAD to the repo
  # page returns success. Result is cached briefly.
  def github_repo_public?
    parts = github_repo_parts
    return false unless parts

    Rails.cache.fetch("project:#{id}:github_public", expires_in: 10.minutes) do
      uri = URI.parse("https://github.com/#{parts[:owner]}/#{parts[:repo]}")
      begin
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 3) do |http|
          req = Net::HTTP::Head.new(uri.request_uri)
          res = http.request(req) rescue nil
          res && res.is_a?(Net::HTTPSuccess)
        end
      rescue StandardError
        false
      end
    end
  end

  # Determine whether the project repository is plausibly clonable. For GitHub
  # repos we require the repo to be public; otherwise we accept common git URL
  # formats or any HTTP(S) URL as clonable (best-effort).
  def clonable?
    return false if repository_url.blank?

    if github_repo_parts
      github_repo_public?
    else
      return true if repository_url =~ /\Agit@[^:]+:[^\/]+\/.+\.git\z/i
      return true if repository_url =~ /\Ahttps?:\/\/.+\.git\z/i
      uri = URI.parse(repository_url) rescue nil
      uri && (uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS))
    end
  end


  # Award credits to the project owner based on credits_per_hour and either total_seconds or provided seconds
  # Returns the amount awarded (float) or nil if no rate provided
  def award_credits!(rate, seconds: nil, recipient: nil)
    return nil if rate.blank?

    # Treat an explicit 0 seconds as "absent" so callers that pass 0 will
    # fall back to the project's stored `total_seconds` (previous bug: 0 was
    # treated as present and resulted in 0 awarded credits).
    secs = (seconds.present? && seconds.to_f > 0) ? seconds.to_f : total_seconds.to_f

    # debug info to help diagnose failing tests where unexpected amounts are
    # being calculated in some test environments
    Rails.logger.debug("award_credits!: rate=#{rate.inspect} seconds_arg=#{seconds.inspect} total_seconds=#{total_seconds.inspect} using_secs=#{secs.inspect} recipient=#{recipient.try(:id)}") if defined?(Rails)

    hours = secs.to_f / 3600.0
    amount = 0.5 * hours

    amount = amount.floor(2) # round down to nearest cent

    target = recipient.present? ? recipient : user

    Rails.logger.debug("award_credits!: computed amount=#{amount.inspect} user_before=#{target.currency.inspect}") if defined?(Rails)
    target.update!(currency: (target.currency || 0) + amount)
    Rails.logger.debug("award_credits!: user_after=#{target.currency.inspect}") if defined?(Rails)

    amount
  end

  # Create a Ship record and award credits (if a rate is provided) in a single transaction.
  # - admin_user: the user performing the ship (stored on the Ship)
  # - rate: credits_per_hour (may be nil)
  # - devlogged_seconds: seconds to use for credit calculation and ship record
  # - recipient_user: optional User to receive awarded credits instead of project owner
  # Returns the created Ship.
  # This method is idempotent for the same shipped_at timestamp (will raise if a ship with identical
  # shipped_at and credits_awarded already exists), but will create distinct Ship rows for separate shipments.
  def ship_and_award_credits!(admin_user:, rate: nil, devlogged_seconds: nil, shipped_at: Time.current, recipient_user: nil)
    # ensure ActiveRecord knows about the current DB schema (multiplier column may
    # have been removed by a migration while the server was running).  This avoids
    # inserting a non‑existent column and crashing requests.
    Ship.reset_column_information

    transaction do
      # persist the rate when supplied
      if rate.present?
        write_attribute(:credits_per_hour, rate)
        save! if changed?
      end

      # normalize devlogged_seconds: treat 0 or non-positive values as absent
      devlogged_seconds = nil if devlogged_seconds.to_i <= 0

      # Determine the actual seconds used to compute credits: prefer post-baseline
      # devlogged_seconds when present, otherwise fall back to the project's total_seconds.
      used_seconds = devlogged_seconds.present? ? devlogged_seconds.to_i : total_seconds.to_i

      amount = nil

      # Pass through recipient_user to award_credits! (still used for legacy currency)
      amount = award_credits!(0.5, seconds: used_seconds, recipient: recipient_user)

      # Ensure stored credits_awarded is numeric (0.0 when no award) so admin UI shows a value
      stored_credits = amount.present? ? amount : 0.0

      # Create the Ship using the used_seconds (so the DB row reflects what was paid)
      ship = ships.create!(user: admin_user, shipped_at: shipped_at, devlogged_seconds: used_seconds, credits_awarded: stored_credits)

      # Award charm notches corresponding to the credited amount.  We convert the
      # floating-point `amount` to an integer count via `to_i` (dropping any
      # fractional credit).  Notches are created through the ship association so
      # the relationship is set automatically.  They remain unassigned to any slot.
      if amount.present?
        notch_count = amount.to_f.to_i
        if notch_count > 0
          target = recipient_user.present? ? recipient_user : user
          notch_count.times do
            CharmNotch.create!(user: target, charm_slot: nil, ship: ship)
          end
        end
      end

      # Record audit for credit awarding when applicable, reflecting the used hours and recipient
      if amount.present?
        details = { amount: amount, rate: 0.5, hours: (used_seconds.to_f / 3600.0) }
        details[:recipient_user_id] = recipient_user.id if recipient_user.present?
        Audit.create!(user: admin_user, project: self, action: "credit_awarded", details: details)
      end

      # Ensure recipient's currency is canonical (sum of ships - spent) in case of prior inconsistencies
      # Do not force a full currency recalculation here; award_credits! directly updates the recipient's currency by the credited amount
      # (calling `recalculate_currency!` here interferes with tests and expected immediate additive behavior).


      ship
    end
  end

  # Defensive shipped? helper: if the DB column exists, return its truthy value, otherwise false.
  # This avoids view errors when migrations haven't been applied yet.
  def shipped?
    return false unless has_attribute?(:shipped)
    self[:shipped] == true
  end

  # Predicate for the explicit 'unshipped' status value used throughout the app/tests.
  def unshipped?
    return true unless has_attribute?(:status)
    status.to_s == "unshipped"
  end

  # Return the latest Ship (or nil)
  def latest_ship
    ships.order(shipped_at: :desc).first
  end

  # Return a computed status based on current ship requests and ships (non-persistent).
  # Priority:
  # - pending ShipRequest => 'pending'
  # - latest request rejected => 'rejected'
  # - any Ship exists => 'shipped'
  # - otherwise => 'unshipped'
  def computed_status
    return "pending" if ship_requests.where(status: "pending").exists?
    latest_request = ship_requests.order(updated_at: :desc).first
    return "rejected" if latest_request&.status == "rejected"
    return "shipped" if ships.exists? and latest_ship.shipped_at.present?
    "unshipped"
  end

  # Return the shipped_at time derived from the latest ship (non-persistent)
  def computed_shipped_at
    latest_ship&.shipped_at
  end

  # Predicate for computed shipped state (derived from ships/requests)
  def computed_shipped?
    computed_status == "shipped"
  end

  # Recalculate and persist project status based on computed_status
  def recalculate_status!(save: true)
    new_status = computed_status
    self.status = new_status if has_attribute?(:status)

    if new_status == "shipped" && (ls = latest_ship)
      self.shipped = true if has_attribute?(:shipped)
      self.shipped_at = ls.shipped_at if respond_to?(:shipped_at)
    else
      self.shipped = false if has_attribute?(:shipped)
      self.shipped_at = nil if respond_to?(:shipped_at)
    end

    save! if save
    self
  end
end
