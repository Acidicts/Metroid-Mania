class Achievement < ApplicationRecord
  has_many :user_achievements, dependent: :destroy
  has_many :users, through: :user_achievements

  # temporary file field for uploads (handled in controller or via JS)
  attr_accessor :image_upload

  before_save :upload_image_file

  private

  def upload_image_file
    return unless image_upload.respond_to?(:path) || image_upload.respond_to?(:read)
    res = CdnService.upload(image_upload)
    self.image_url = res["url"] if res && res["url"].present?
  rescue => e
    Rails.logger.error("Achievement image upload failed: #{e.message}")
  end

  public

  # Supported requirement types.
  # requirement_value holds the threshold (any number).
  REQUIREMENT_TYPES = %w[min_notches min_charms min_hours].freeze

  validates :requirement_type, inclusion: { in: REQUIREMENT_TYPES }, allow_nil: true
  validates :requirement_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Returns true if the given user satisfies this achievement's requirement.
  def earned_by?(user)
    return false if requirement_type.blank? || requirement_value.nil?

    threshold = requirement_value.to_f

    case requirement_type
    when "min_notches"
      user.charm_notches.count >= threshold
    when "min_charms"
      user.charm_slots_orders.count >= threshold
    when "min_hours"
      user.total_devlogged_hours.to_f >= threshold
    else
      false
    end
  end

  # Grant this achievement to a specific user if the requirement is met.
  # Safe to call multiple times — won't double-grant.
  def check_and_grant!(user)
    return unless earned_by?(user)

    user_achievements.find_or_create_by!(user: user) do |ua|
      ua.unlocked_at = Time.current
    end
  end
end
