class Project < ApplicationRecord
  belongs_to :user
  has_many :devlogs, dependent: :destroy
  has_many :ships, dependent: :destroy
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

  # Can an admin ship (approve) this project? Must be pending and have at least 15 minutes of devlogs since baseline
  def eligible_for_admin_ship?
    status == 'pending' && devlogged_minutes_since_baseline >= 15
  end

  # Award credits to the project owner based on credits_per_hour and either total_seconds or provided seconds
  # Returns the amount awarded (float) or nil if no rate provided
  def award_credits!(rate, seconds: nil)
    return nil if rate.blank?

    secs = seconds.present? ? seconds.to_f : total_seconds.to_f
    hours = secs / 3600.0
    amount = rate.to_f * hours

    user.update!(currency: (user.currency || 0) + amount)

    amount
  end

  # Defensive shipped? helper: if the DB column exists, return its truthy value, otherwise false.
  # This avoids view errors when migrations haven't been applied yet.
  def shipped?
    return false unless has_attribute?(:shipped)
    self[:shipped] == true
  end
end
