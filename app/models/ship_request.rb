class ShipRequest < ApplicationRecord
  belongs_to :project
  belongs_to :user
  belongs_to :processed_by, class_name: "User", optional: true
  belongs_to :ship, optional: true

  has_many :devlogs

  STATUSES = %w[pending approved rejected].freeze

  validates :status, inclusion: { in: STATUSES }

  after_commit :recalculate_project_status, on: [ :create, :update, :destroy ]
  after_create_commit :create_ship_request_devlog
  after_update_commit :sync_ship_request_devlog
  # When a request is updated after approval, propagate meaningful fields into the associated Ship (if it exists).
  after_update_commit :propagate_changes_to_ship

  def pending?
    status == "pending"
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

      # Use the recorded devlogged seconds directly (seconds precision)
      project.devlogs.create!(title: "Ship request ##{id}", content: content.strip, duration_seconds: devlogged_seconds.to_i, log_date: (requested_at || created_at).to_date, ship_request: self)
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
        ship_number = project.ships.where("shipped_at <= ?", ship.shipped_at).count
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
        Multiplier: #{ciel(credits/formatted_time)}
      TEXT

      d.update_columns(title: title, content: new_content.strip, duration_seconds: devlogged_seconds.to_i)
    rescue => e
      Rails.logger.error "Failed to sync ship request devlog for ShipRequest ##{id}: #{e.message}"
    end

    # Also propagate meaningful changes to an associated Ship (if it exists).
    # e.g. if an admin edits credits_awarded, multiplier, or devlogged_seconds after approval,
    # ensure the Ship row and owner currency stay in sync.
    propagate_changes_to_ship
  end

  public

  # Find a Ship that corresponds to this request. Prefer a ship recorded at the
  # same time as the request's approved_at (when present), otherwise the first
  # ship with shipped_at on or after the request's requested_at.
  def associated_ship
    # Prefer the explicit association when present
    return Ship.find_by(id: ship_id) if ship_id.present?

    return nil unless project.present?

    if approved_at.present?
      # try exact match first (common when associate_pending_request set approved_at to shipped_at)
      ship = project.ships.where(shipped_at: approved_at).order(:id).first
      return ship if ship
    end

    project.ships.where("shipped_at >= ?", requested_at).order(:shipped_at).first
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
    self.devlogged_seconds = devlogs.sum(:duration_seconds).to_i if devlogged_seconds.blank? || devlogged_seconds.to_i <= 0

    # choose rate priority: explicit param -> request value -> project value
    rate = credits_per_hour.presence || self.credits_per_hour.presence || project.credits_per_hour

    # Find recipient user if supplied (if nil, award to project.user inside Project#award_credits!)
    recipient = User.find_by(id: recipient_user_id) if recipient_user_id.present?

    base_rate = rate

    # If a multiplier is present, apply it to the chosen rate for this approval (do not permanently change project base rate)
    if respond_to?(:multiplier) && multiplier.present? && base_rate.present?
      effective_rate = base_rate.to_f * multiplier.to_f
    else
      effective_rate = base_rate
    end

    ship = project.ship_and_award_credits!(admin_user: admin_user, rate: effective_rate, devlogged_seconds: devlogged_seconds, shipped_at: Time.current, recipient_user: recipient)

    # If this request carried a multiplier, persist that to the created Ship as well
    if respond_to?(:multiplier) && multiplier.present?
      begin
        # persist multiplier without triggering ship callbacks (avoids double-calculation)
        ship.update_columns(multiplier: multiplier, updated_at: Time.current)
      rescue => e
        Rails.logger.error "Failed to set multiplier on Ship ##{ship.id}: #{e.message}"
      end
    end

    # If we temporarily applied an effective_rate that differs from the base, restore the project's stored credits_per_hour
    if base_rate.present? && effective_rate.present? && effective_rate.to_f != base_rate.to_f
      begin
        project.update!(credits_per_hour: base_rate)
      rescue => e
        Rails.logger.error "Failed to restore project credits_per_hour after applying multiplier for ShipRequest ##{id}: #{e.message}"
      end
    end

    # Link the request directly to the created Ship so future updates can operate on the same row.
    update!(status: "approved", approved_at: Time.current, processed_by: admin_user, credits_awarded: ship.credits_awarded, devlogged_seconds: ship.devlogged_seconds, ship_id: ship.id)

    # ensure project status reflects this approved ship
    project.recalculate_status!

    ship
  end

  def reject!(admin_user:)
    transaction do
      # If a Ship was already created for this request, reverse awarded credits (if any)
      if (ship = associated_ship)
        begin
          old_credits = ship.credits_awarded.to_f
          if old_credits != 0.0
            ship.update!(credits_awarded: 0.0)
            owner = project.user
            owner.update!(currency: (owner.currency || 0) - old_credits)
            Audit.create!(user: admin_user, project: project, action: "reverse_ship_credits", details: { ship_id: ship.id, reversed_amount: old_credits, request_id: id })
          end
        rescue => e
          Rails.logger.error "Failed to reverse credits for Ship ##{ship.id} on rejection of ShipRequest ##{id}: #{e.message}"
        end
      end

      # Dissociate any project devlogs that were linked to this ship request so they
      # can be re-used by a future ship request. Do this before updating the system
      # devlog (which we preserve but mark as rejected and clear its duration).
      begin
        project.devlogs.where(ship_request_id: id).update_all(ship_request_id: nil)
      rescue => e
        Rails.logger.error "Failed to dissociate devlogs for ShipRequest ##{id}: #{e.message}"
      end

      # Preserve the system devlog but mark it rejected and clear duration_seconds
      begin
        d = project.devlogs.find_by(title: "Ship request ##{id}") || project.devlogs.where(title: "Ship request ##{id}").order(:created_at).first
        if d
          d.update_columns(title: "Rejected ship request ##{id}", duration_seconds: nil, ship_request_id: nil, updated_at: Time.current)
        end
      rescue => e
        Rails.logger.error "Failed to update devlog for rejected ShipRequest ##{id}: #{e.message}"
      end

      update!(status: "rejected", approved_at: Time.current, processed_by: admin_user, ship_id: ship&.id)
      project.recalculate_status!
    end
  end

  private

  def recalculate_project_status
    # Skip recalculation if the associated project is being destroyed or is not persisted
    return unless project.present? && project.persisted?

    project.recalculate_status!
  end

  # Propagate certain fields from a ShipRequest into its associated Ship when present.
  # - credits_awarded: adjusts owner currency by the delta and updates ship.credits_awarded
  # - devlogged_seconds: updates ship.devlogged_seconds
  # - multiplier: persists multiplier on the ship
  def propagate_changes_to_ship
    ship = associated_ship
    return unless ship

    # Ensure multiplier stays in sync when request/ship first meet or on load
    sync_multiplier_with_ship

    attrs = {}
    if saved_change_to_credits_awarded?
      attrs[:credits_awarded] = credits_awarded.to_f
    end

    if saved_change_to_devlogged_seconds?
      attrs[:devlogged_seconds] = devlogged_seconds.to_i
    end

    if respond_to?(:multiplier) && saved_change_to_multiplier?
      attrs[:multiplier] = multiplier

      # If the project has a credits_per_hour base rate, re-calculate the ship's credited amount
      # so the multiplier is directly linked to credits_per_hour. Use the ship's devlogged_seconds if
      # present, otherwise fall back to the request's stored seconds.
      if project&.credits_per_hour.present?
        seconds = (ship&.devlogged_seconds || devlogged_seconds || 0).to_f
        computed_credits = (project.credits_per_hour.to_f * multiplier.to_f * (seconds / 3600.0))
        attrs[:credits_awarded] = computed_credits.round(6)
      end
    end

    return if attrs.empty?

    begin
      ActiveRecord::Base.transaction do
        if attrs.key?(:credits_awarded)
          old_credits = ship.credits_awarded.to_f
          new_credits = attrs[:credits_awarded]
          credits_delta = new_credits - old_credits

          ship.update!(attrs) # includes credits_awarded

          owner = project.user
          # Recalculate the owner's currency to ensure it remains in sync with ships and spent amount
          begin
            owner.recalculate_currency!
          rescue => e
            Rails.logger.error("Failed to recalculate currency for User ##{owner&.id}: #{e.message}")
          end

          Audit.create!(user: processed_by || user, project: project, action: "adjust_ship_credits_via_request", details: { ship_id: ship.id, delta: credits_delta, new_credits: new_credits, request_id: id })
        else
          ship.update!(attrs)
        end

        Audit.create!(user: processed_by || user, project: project, action: "sync_ship_from_request", details: { ship_id: ship.id, changes: attrs, request_id: id })
      end
    rescue => e
      Rails.logger.error "Failed to propagate changes to Ship ##{ship.id}: #{e.message}"
    end
  end

  # Ensure multiplier is synchronized between this request and its associated Ship (if present).
  # Preference & rules:
  # - If the ship has a multiplier but the request doesn't, copy ship -> request.
  # - If the request has a multiplier but ship doesn't, copy request -> ship (will trigger ship recalculation).
  # - If both exist but differ, prefer the Ship value and copy it into the request.
  def sync_multiplier_with_ship
    ship = associated_ship
    return unless ship

    begin
      if ship.multiplier.present? && (multiplier.blank? || multiplier.to_f != ship.multiplier.to_f)
        # Ship has authoritative multiplier; persist it to the request
        update!(multiplier: ship.multiplier)
        return
      end

      if multiplier.present? && (ship.multiplier.blank? || ship.multiplier.to_f != multiplier.to_f)
        # Request had multiplier that ship lacks; set on ship so it recalculates
        ship.update!(multiplier: multiplier)
      end
    rescue => e
      Rails.logger.error "Failed to sync multiplier for ShipRequest ##{id} and Ship ##{ship&.id}: #{e.message}"
    end
  end
end
