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
end
