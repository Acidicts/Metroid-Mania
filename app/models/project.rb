class Project < ApplicationRecord
  belongs_to :user
  has_many :devlogs, dependent: :destroy
  has_many :ships, dependent: :destroy
  has_many :ship_requests, dependent: :nullify
  has_many :audits, dependent: :nullify

  # Attach a representative image for the project (Active Storage)
  has_one_attached :image
  
  validates :name, presence: true
  validates :repository_url, presence: true

  # Store multiple Hackatime project names in the text `hackatime_ids` column as YAML.
  # Provide simple accessor helpers so the model behaves like an Array.
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

  def hackatime_ids=(vals)
    write_attribute(:hackatime_ids, vals.present? ? vals.to_yaml : nil)
  end

  def total_devlogged_seconds
    devlogs.sum(:duration_minutes) * 60
  end

  # Return array of target names to query in Hackatime. Backwards compatible with `hackatime_id`.
  def hackatime_targets
    if hackatime_ids.present? && hackatime_ids.any?
      hackatime_ids.map(&:to_s)
    elsif respond_to?(:hackatime_id) && hackatime_id.present?
      [hackatime_id.to_s]
    else
      [name]
    end
  end

  def update_time_from_hackatime!
    return unless user.slack_id.present?

    service = HackatimeService.new(slack_id: user.slack_id)
    total = hackatime_targets.sum { |t| service.get_project_stats(t).to_i }
    update(total_seconds: total) if total > 0
  end

  def time
    remaining = [total_seconds.to_i - total_devlogged_seconds, 0].max
    hours = (remaining / 3600).floor
    minutes = ((remaining % 3600) / 60).floor
    "#{hours} hrs #{minutes} mins"
  end

  # Ensure hackatime projects are not linked to multiple projects
  validate :hackatime_ids_unique_across_projects

  private

  def hackatime_ids_unique_across_projects
    return if hackatime_ids.blank?

    other_names = Project.where.not(id: id).flat_map(&:hackatime_ids).map(&:to_s)
    overlap = hackatime_ids.map(&:to_s) & other_names
    if overlap.any?
      errors.add(:hackatime_ids, "contains project(s) already linked: #{overlap.join(', ')}")
    end
  end

  public

  # Allowed statuses for projects
  STATUSES = %w[unshipped pending shipped rejected].freeze

  # Set default status for new projects
  before_create do
    self.status ||= 'unshipped'
    # Only set shipped to false by default if it's currently nil
    self.shipped = false if respond_to?(:shipped) && self.shipped.nil?
  end

  # Baseline timestamp used to calculate whether enough work has been done since creation or last ship
  def ship_baseline
    shipped_at || created_at
  end

  # Minutes of devlogged work created since baseline
  def devlogged_minutes_since_baseline
    devlogs.where('created_at >= ?', ship_baseline).sum(:duration_minutes).to_i
  end

  # Can the owner request a ship? Must not already be pending and at least 15 minutes of devlogs since baseline
  def eligible_for_ship_request?
    return false if status == 'pending'
    devlogged_minutes_since_baseline >= 15
  end

  # Minutes still required for the owner to be able to request a ship (0 when eligible)
  def minutes_needed_for_ship_request
    [15 - devlogged_minutes_since_baseline.to_i, 0].max
  end

  # Can an admin ship (approve) this project? Must be pending and have at least 15 minutes of devlogs since baseline
  def eligible_for_admin_ship?
    # Admins may approve/ship a pending project when either:
    # - there are >= 15 minutes of devlogs since the baseline (owner-requested work), OR
    # - the project already has sufficient recorded total_seconds (admin fallback).
    return false unless status == 'pending'
    devlogged_minutes_since_baseline >= 15 || total_seconds.to_i >= 15.minutes.to_i
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
    amount = rate.to_f * hours

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
      if rate.present?
        # Pass through recipient_user to award_credits!
        amount = award_credits!(rate, seconds: used_seconds, recipient: recipient_user)
      end

      # Ensure stored credits_awarded is numeric (0.0 when no award) so admin UI shows a value
      stored_credits = amount.present? ? amount : 0.0

      # Create the Ship using the used_seconds (so the DB row reflects what was paid)
      ship = ships.create!(user: admin_user, shipped_at: shipped_at, devlogged_seconds: used_seconds, credits_awarded: stored_credits)

      # Record audit for credit awarding when applicable, reflecting the used hours and recipient
      if amount.present?
        details = { amount: amount, rate: rate, hours: (used_seconds.to_f / 3600.0) }
        details[:recipient_user_id] = recipient_user.id if recipient_user.present?
        Audit.create!(user: admin_user, project: self, action: 'credit_awarded', details: details)
      end

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
    status.to_s == 'unshipped'
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
    return 'pending' if ship_requests.where(status: 'pending').exists?
    latest_request = ship_requests.order(updated_at: :desc).first
    return 'rejected' if latest_request&.status == 'rejected'
    return 'shipped' if ships.exists?
    'unshipped'
  end

  # Return the shipped_at time derived from the latest ship (non-persistent)
  def computed_shipped_at
    latest_ship&.shipped_at
  end

  # Predicate for computed shipped state (derived from ships/requests)
  def computed_shipped?
    computed_status == 'shipped'
  end

  # Recalculate and persist project status based on computed_status
  def recalculate_status!(save: true)
    new_status = computed_status
    self.status = new_status if has_attribute?(:status)

    if new_status == 'shipped' && (ls = latest_ship)
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
