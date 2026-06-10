# == Schema Information
#
# Table name: sales
#
#  id               :bigint           not null, primary key
#  created_at       :datetime         not null
#  description      :text
#  discount_notches :integer          default: 0, not null
#  ends_at          :datetime
#  name             :string           not null
#  product_id       :integer
#  quantity         :integer          default: 1, not null
#  starts_at        :datetime
#  updated_at       :datetime         not null
#
# Indexes
#  index_sales_on_product_id  (product_id)
#
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
