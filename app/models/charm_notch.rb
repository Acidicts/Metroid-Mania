class CharmNotch < ApplicationRecord
  belongs_to :user
  belongs_to :charm_slot, optional: true, default: nil

  # ensure we never save a notch pointing at a slot with a missing order
  # the original `validate :assigned` callback was being used as a side-
  # effect method, and calling `notch.assigned` directly in the console
  # would clear the attribute in memory but never persist it.  the return
  # value was also confusing (it happens to be whatever `Rails.logger.info`
  # returns).
  before_validation :clear_slot_if_unordered

  # a convenience predicate that mirrors the old method name and can be
  # used from other code (note the question mark)
  def assigned?
    charm_slot.present?
  end

  private

  def clear_slot_if_unordered
    return unless charm_slot

    if charm_slot.order_id.blank?
      Rails.logger.info("charm_slot cleared because order_id is nil")
      self.charm_slot = nil
      self.save!
    else
      Rails.logger.info("charm_slot.order_id: #{charm_slot.order_id}")
    end
  end

  def submitted?
    order = charm_slot&.order
    order.present? && (order.submitted? || order.fulfilled?)
  end
end
