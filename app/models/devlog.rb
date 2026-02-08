class Devlog < ApplicationRecord
  belongs_to :project
  belongs_to :ship_request, optional: true
  belongs_to :user, optional: true

  # Duration must be an integer and present.
  # Owner-created devlogs must be at least 1 minute; system-generated devlogs (tied to ShipRequest)
  # are allowed to be zero minutes (used to represent ships/ship-requests).
  validates :duration_minutes, presence: true,
                               numericality: { only_integer: true, greater_than_or_equal_to: 0, message: "must be a non-negative integer" }

  validate :owner_minimum_duration

  # Indicates whether a given user may edit this devlog. System-generated devlogs
  # (those tied to a ShipRequest) are never editable.
  def editable_by?(u)
    return false if u.nil?
    return true if u.admin? || u.superadmin?

    # System-generated devlogs are not editable by normal users
    return false if ship_request.present?

    user == u
  end

  private

  def owner_minimum_duration
    # If this is not a system-generated entry, ensure at least 1 minute
    return if ship_request.present?
    if duration_minutes.nil? || duration_minutes.to_i < 1
      errors.add(:duration_minutes, "must be at least 1 minute")
    end
  end
end
