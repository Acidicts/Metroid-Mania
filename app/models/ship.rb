class Ship < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :devlogged_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :credits_awarded, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  after_create :touch_project_status
  after_create :associate_pending_request
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
end
