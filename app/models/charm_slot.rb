# == Schema Information
#
# Table name: charm_slots
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  order_id   :integer
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#  index_charm_slots_on_order_id  (order_id)
#  index_charm_slots_on_user_id   (user_id)
#
class CharmSlot < ApplicationRecord
  belongs_to :user
  belongs_to :order, optional: true, default: nil, inverse_of: :charm_slot

  # each slot may have zero or more notches; having this association lets us
  # query or clean up orphaned slots.
  has_many :charm_notches, dependent: :nullify

  validates :user_id, presence: true
  validates :order_id, uniqueness: true, allow_nil: true

  validate :ensure_slot_order_is_not_placeholder

  def ensure_slot_order_is_not_placeholder
    if order && order.name == "Charm slot placeholder"
      self.order = nil
    end
  end

  def get_charm_notches
    order = Order.find(self.order_id)
    return unless order.notch_cost > self.charm_notches.count
    notches = CharmNotch.where(charm_slot_id: nil)
    return if notches.count < (order.notch_cost - self.charm_notches.count)
    notches.limit(order.notch_cost - self.charm_notches.count).update_all(charm_slot_id: self.id)
  end

  def order_status
    order&.status
  end

  def submitted?
    order.present? && (order.submitted? || order.fulfilled?)
  end
end
