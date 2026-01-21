class ShipRequest < ApplicationRecord
  belongs_to :project
  belongs_to :user
  belongs_to :processed_by, class_name: 'User', optional: true

  has_many :devlogs

  STATUSES = %w[pending approved rejected].freeze

  validates :status, inclusion: { in: STATUSES }

  after_commit :recalculate_project_status, on: [:create, :update, :destroy]

  def pending?
    status == 'pending'
  end

  # Find a Ship that corresponds to this request. Prefer a ship recorded at the
  # same time as the request's approved_at (when present), otherwise the first
  # ship with shipped_at on or after the request's requested_at.
  def associated_ship
    return nil unless project.present?

    if approved_at.present?
      # try exact match first (common when associate_pending_request set approved_at to shipped_at)
      ship = project.ships.where(shipped_at: approved_at).order(:id).first
      return ship if ship
    end

    project.ships.where('shipped_at >= ?', requested_at).order(:shipped_at).first
  end

  # Prefer stored credits_awarded, but fall back to the associated ship's credited amount when missing
  def effective_credits_awarded
    return credits_awarded if credits_awarded.present?
    associated_ship&.credits_awarded
  end

  # Approve this request: create the Ship (via project helper which awards credits)
  # Returns the created Ship record
  def approve!(admin_user:, credits_per_hour: nil, recipient_user_id: nil)
    raise "cannot approve non-pending request" unless pending?

    # Compute the devlogged seconds if not already stored
    self.devlogged_seconds = (devlogs.sum(:duration_minutes) * 60).to_i if devlogged_seconds.blank? || devlogged_seconds.to_i <= 0

    # choose rate priority: explicit param -> request value -> project value
    rate = credits_per_hour.presence || self.credits_per_hour.presence || project.credits_per_hour

    # Find recipient user if supplied (if nil, award to project.user inside Project#award_credits!)
    recipient = User.find_by(id: recipient_user_id) if recipient_user_id.present?

    ship = project.ship_and_award_credits!(admin_user: admin_user, rate: rate, devlogged_seconds: devlogged_seconds, shipped_at: Time.current, recipient_user: recipient)

    update!(status: 'approved', approved_at: Time.current, processed_by: admin_user, credits_awarded: ship.credits_awarded, devlogged_seconds: ship.devlogged_seconds)

    # ensure project status reflects this approved ship
    project.recalculate_status!

    ship
  end

  def reject!(admin_user:)
    update!(status: 'rejected', approved_at: Time.current, processed_by: admin_user)
    project.recalculate_status!
  end

  private

  def recalculate_project_status
    project.recalculate_status! if project.present?
  end
end
