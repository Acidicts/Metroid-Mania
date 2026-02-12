class Devlog < ApplicationRecord
  belongs_to :project, counter_cache: true
  belongs_to :ship_request, optional: true
  belongs_to :user, optional: true

  # Duration is stored in seconds (new). Keep compatibility with existing duration_minutes;
  # owner-created devlogs must be at least 1 minute; system-generated devlogs (tied to ShipRequest)
  # are allowed to be zero seconds (used to represent ships/ship-requests).
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0, message: "must be a non-negative integer" }, allow_nil: true

  validate :owner_minimum_duration
  before_validation :ensure_duration_seconds

  # Indicates whether a given user may edit this devlog. System-generated devlogs
  # (those tied to a ShipRequest) are never editable.
  def editable_by?(u)
    return false if u.nil?
    return true if u.admin? || u.superadmin?

    # System-generated devlogs are not editable by normal users
    return false if ship_request.present?

    user == u
  end

  # Returns the authoritative duration in seconds, falling back to legacy minutes when needed.
  def duration_seconds_total
    return duration_seconds if duration_seconds.present?
    return duration_minutes.to_i * 60 if duration_minutes.present?
    nil
  end

  private

  def ensure_duration_seconds
    if duration_seconds.blank? && duration_minutes.present?
      self.duration_seconds = duration_minutes.to_i * 60
    end
  end

  def owner_minimum_duration
    # If this is not a system-generated entry, ensure at least 1 minute
    return if ship_request.present?
    secs = duration_seconds_total
    if secs.nil? || secs < 60
      errors.add(:duration_minutes, "must be at least 1 minute")
    end
  end
end
