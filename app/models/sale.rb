class Sale < ApplicationRecord
  belongs_to :product, optional: true

  validates :name, presence: true
  # discount_notches is an integer number of notches to deduct from the regular cost
  validates :discount_notches, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, if: -> { product_id.present? }
  validate :ends_after_start

  scope :active, -> { where("starts_at <= ? AND (ends_at IS NULL OR ends_at >= ?)", Time.current, Time.current) }

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?
    if ends_at < starts_at
      errors.add(:ends_at, "must be after the start time")
    end
  end
end
