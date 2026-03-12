class CharmNotch < ApplicationRecord
  belongs_to :user
  belongs_to :ship, optional: true
  belongs_to :charm_slot, optional: true, default: nil

  # flag used for notches manually granted by an admin via the admin UI.
  # Historically these were encoded with `ship_id = -1`, but we now migrate to
  # a proper boolean column and ensure the value is never removed by
  # reconciliation or user adjustments.
  attribute :admin_granted, :boolean, default: false

  scope :non_admin, -> { where(admin_granted: false) }
  scope :admin_only, -> { where(admin_granted: true) }

  def admin?
    admin_granted
  end

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

  # Whenever a user gains or loses a notch we may have crossed an achievement
  # threshold.  Historically the only trigger for achievement evaluation was
  # the creation of devlogs, so any notches added via reconciliation, admin
  # grants, rake tasks, etc. would never surface related badges.  Adding an
  # `after_commit` hook ensures the user's `evaluate_achievements!` logic runs
  # automatically whenever a record is created or destroyed.
  after_commit :evaluate_user_achievements, on: [ :create, :destroy ]

  validate :has_ship

  def has_ship
    if self.ship_id.nil? && !admin_granted
      self.destroy
    end
  end

  private

  def evaluate_user_achievements
    # guard against orphaned records; user may be nil during tests
    user&.evaluate_achievements!
  end

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
