class CharmSlot < ApplicationRecord
  belongs_to :user
  belongs_to :order, optional: true, default: nil

  validates :user_id, presence: true
  validates :order_id, uniqueness: true, allow_nil: true

  validate :ensure_slot_order_is_not_placeholder

  def ensure_slot_order_is_not_placeholder
    if order && order.name == "Charm slot placeholder"
      self.order = nil
    end
  end
end
