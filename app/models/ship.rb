class Ship < ApplicationRecord
  belongs_to :project, counter_cache: true
  belongs_to :user

  validates :devlogged_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :credits_awarded, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  after_create :touch_project_status
  after_create :associate_pending_request
  after_update :apply_multiplier_change, if: -> { saved_change_to_multiplier? }
  after_destroy :touch_project_status

  private

  def touch_project_status
    project.recalculate_status! if project.present?
  end

  # If there is a pending ShipRequest that matches this ship (requested before shipped_at),
  # update the request to 'approved' and set credits_awarded so the UI reflects the ship.
  def associate_pending_request
    return unless project.present? && shipped_at.present?

    req = project.ship_requests.where(status: 'pending').where('requested_at <= ?', shipped_at).order(requested_at: :desc).first
    return unless req

    begin
      req.update!(status: 'approved', approved_at: shipped_at, processed_by: user, credits_awarded: credits_awarded, devlogged_seconds: (devlogged_seconds || req.devlogged_seconds))
      Audit.create!(user: user, project: project, action: 'approve_via_ship', details: { ship_id: id, ship_request_id: req.id, credits_awarded: credits_awarded })
    rescue => e
      Rails.logger.error("associate_pending_request failed for Ship #{id}: #{e.message}")
    end
  end

  # When the multiplier on a Ship changes, re-calculate its credited amount based on
  # project's base credits_per_hour (if present) and the ship's recorded devlogged_seconds.
  # Adjust the owner's currency by the delta and record an Audit.
  def apply_multiplier_change
    return unless multiplier.present? && project&.credits_per_hour.present?

    seconds = (devlogged_seconds.present? && devlogged_seconds.to_i > 0) ? devlogged_seconds.to_f : project.total_seconds.to_f
    new_credits = (project.credits_per_hour.to_f * multiplier.to_f * (seconds / 3600.0)).round(6)
    old_credits = credits_awarded.to_f
    delta = new_credits - old_credits
    return if delta == 0.0

    begin
      ActiveRecord::Base.transaction do
        # update credits without triggering callbacks to avoid recursion
        update_columns(credits_awarded: new_credits, updated_at: Time.current)

        owner = project.user
        # Recalculate owner's currency from the canonical source (sum of ships - spent)
        begin
          owner.recalculate_currency!
        rescue => e
          Rails.logger.error("Failed to recalculate currency for User ##{owner&.id}: #{e.message}")
        end

        Audit.create!(user: (user || owner), project: project, action: 'apply_multiplier', details: { ship_id: id, multiplier: multiplier, delta: delta, new_credits: new_credits })
      end
    rescue => e
      Rails.logger.error("apply_multiplier_change failed for Ship #{id}: #{e.message}")
    end
  end

  # Ensure multiplier synchronization with an associated ShipRequest when a page loads.
  # Preference: Ship multiplier is authoritative; if request differs or lacks it, update request.
  # If request has multiplier and ship doesn't, set ship multiplier (which triggers recalculation).
  def sync_multiplier_with_request
    return unless project.present?

    req = project.ship_requests.find_by(ship_id: id) || project.ship_requests.where('requested_at <= ?', shipped_at).order(requested_at: :desc).first
    return unless req

    begin
      if multiplier.present? && (req.multiplier.blank? || req.multiplier.to_f != multiplier.to_f)
        req.update!(multiplier: multiplier)
        return
      end

      if req.multiplier.present? && (multiplier.blank? || multiplier.to_f != req.multiplier.to_f)
        update!(multiplier: req.multiplier)
      end
    rescue => e
      Rails.logger.error("Failed to sync multiplier for Ship #{id} with ShipRequest ##{req&.id}: #{e.message}")
    end
  end
end
