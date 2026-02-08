class ShipRequest < ApplicationRecord
  belongs_to :project
  belongs_to :user
  belongs_to :processed_by, class_name: 'User', optional: true

  has_many :devlogs

  STATUSES = %w[pending approved rejected].freeze

  validates :status, inclusion: { in: STATUSES }

  after_commit :recalculate_project_status, on: [:create, :update, :destroy]
  after_create_commit :create_ship_request_devlog
  after_update_commit :sync_ship_request_devlog

  def pending?
    status == 'pending'
  end

  private

  # Create a non-editable devlog representing this ship request.
  def create_ship_request_devlog
    begin
      # Human-friendly duration. Use helper when possible.
      formatted_time = if devlogged_seconds.present? && devlogged_seconds.to_i > 0
                         ApplicationController.helpers.format_duration(devlogged_seconds.to_i)
                       else
                         "-"
                       end

      credits = credits_awarded.present? ? credits_awarded : "-"
      multiplier = respond_to?(:multiplier) && multiplier.present? ? multiplier : "-"

      content = <<~TEXT
        Time in ship: #{formatted_time}
        Requested at: #{requested_at || created_at}
        Credits earned: #{credits}
        Multiplier: #{multiplier}
      TEXT

      # Use the recorded devlogged seconds to compute minutes; allow 0 minutes for system entries
      duration_min = (devlogged_seconds.to_i / 60).to_i

      project.devlogs.create!(title: "Ship request ##{id}", content: content.strip, duration_minutes: duration_min, log_date: (requested_at || created_at).to_date, ship_request: self)
    rescue => e
      Rails.logger.error "Failed to create ship request devlog for ShipRequest ##{id}: #{e.message}"
    end
  end

  # Update the system devlog when the ship request is updated (e.g. credits awarded)
  def sync_ship_request_devlog
    d = devlogs.find_by(title: "Ship request ##{id}") || devlogs.where(ship_request: self).order(:created_at).first
    return unless d

    begin
      formatted_time = if devlogged_seconds.present? && devlogged_seconds.to_i > 0
                         ApplicationController.helpers.format_duration(devlogged_seconds.to_i)
                       else
                         "-"
                       end

      credits = credits_awarded.present? ? credits_awarded : "-"
      multiplier = respond_to?(:multiplier) && multiplier.present? ? multiplier : "-"

      # If a Ship has been created for this request, show Ship # and awarded credits
      ship = associated_ship
      if ship
        ship_number = project.ships.where('shipped_at <= ?', ship.shipped_at).count
        title = "Ship ##{ship_number}"
        awarded_credits = ship.credits_awarded.present? ? ApplicationController.helpers.format_credits(ship.credits_awarded) : "-"
        credits_line = "Credits awarded to owner: #{awarded_credits}"
      else
        title = "Ship request ##{id}"
        credits_line = "Credits earned: #{credits}"
      end

      new_content = <<~TEXT
        Time in ship: #{formatted_time}
        Requested at: #{requested_at || created_at}
        #{credits_line}
        Multiplier: #{multiplier}
      TEXT

      d.update_columns(title: title, content: new_content.strip, duration_minutes: (devlogged_seconds.to_i / 60).to_i)
    rescue => e
      Rails.logger.error "Failed to sync ship request devlog for ShipRequest ##{id}: #{e.message}"
    end
  end

  public

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

  public

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
    # Skip recalculation if the associated project is being destroyed or is not persisted
    return unless project.present? && project.persisted?

    project.recalculate_status!
  end
end
