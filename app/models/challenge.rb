class Challenge < ApplicationRecord
  # A challenge grants players bonus notches when
  # they meet the criteria within the specified window.
  #
  # The database column `type` is used for categorizing challenges but is a
  # reserved name in Rails (STI).  Disable inheritance so Rails treats it as a
  # normal attribute.
  self.inheritance_column = :_type_disabled

  # Rails won't apply a database default when AR assigns `nil` explicitly, so
  # set an application-level default as well.  This ensures new records get the
  # expected value without needing to reload from the database.
  attribute :type, :string, default: "multiplier"


  validates :title, presence: true
  validates :reward_notches, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :multiplier, numericality: { greater_than: 0 }, allow_nil: true
  validates :type, presence: true
  validate :end_after_start
  validate :still_valid

  scope :active, -> { where(active: true).where("start_at <= ? AND end_at >= ?", Time.current, Time.current) }

  # returns the challenge(s) active right now
  def self.current
    active
  end

  # calculates extra notches awarded for a given base count
  # multiplier is the total factor (1.5 means 50% bonus)
  def bonus_for(count)
    return 0 unless multiplier
    (count * (multiplier - 1)).floor
  end

  def still_valid
    if active && end_at < Time.current
      self.active = false
      save!
    end
  end

  private

  def end_after_start
    return if start_at.blank? || end_at.blank?
    errors.add(:end_at, "must be after the start time") if end_at < start_at
  end
end
