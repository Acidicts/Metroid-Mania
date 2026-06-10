# == Schema Information
#
# Table name: ship_requests
#
#  id                 :bigint           not null, primary key
#  approved_at        :datetime
#  created_at         :datetime         not null
#  credits_awarded    :float
#  credits_per_hour   :float
#  devlogged_seconds  :integer
#  multiplier         :float            default: 1.0, not null
#  processed_by_id    :integer
#  project_id         :integer          not null
#  requested_at       :datetime
#  ship_id            :integer
#  status             :string           default: "pending"
#  updated_at         :datetime         not null
#  user_id            :integer          not null
#
# Indexes
#  index_ship_requests_on_processed_by_id  (processed_by_id)
#  index_ship_requests_on_project_id        (project_id)
#  index_ship_requests_on_ship_id           (ship_id)
#  index_ship_requests_on_user_id           (user_id)
#
class ShipRequest < ApplicationRecord
  belongs_to :project
  belongs_to :user
  belongs_to :processed_by, class_name: "User", optional: true
  belongs_to :ship, optional: true

  has_many :devlogs

  STATUSES = %w[pending approved rejected].freeze

  # multiplier corresponds to the active challenge factor when the request was
  # created.  when a ship is approved the value is copied to the ship row as
  # well so the UI and audits can display what bonus applied.  default of 1.0
  # matches the original migration.
  attribute :multiplier, :float, default: 1.0
  validates :multiplier, numericality: { greater_than: 0 }, allow_nil: true

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

      content = <<~TEXT
        Time in ship: #{formatted_time}
        Requested at: #{requested_at || created_at}
        Notches earned: #{credits}
      TEXT

      # Use the recorded devlogged seconds directly (seconds precision)
      project.devlogs.create!(title: "Ship request ##{id}", content: content.strip, duration_seconds: devlogged_seconds.to_i, log_date: (requested_at || created_at).to_date, ship_request: self)
    rescue => e
      Rails.logger.error "Failed to create ship request devlog for ShipRequest ##{id}: #{e.message}"
    end
  end

  # Update the system devlog when the ship request is updated (e.g. credits awarded)
  def sync_ship_request_devlog
    # Only sync the system-generated marker row (user_id is nil). Avoid touching
    # linked user-authored devlogs that share this ship_request_id.
    d = devlogs.where(user_id: nil).find_by(title: "Ship request ##{id}") ||
        devlogs.where(user_id: nil, ship_request: self).order(:created_at).first

    # Legacy data may be missing the marker row; recreate it so future updates
    # have a stable record to modify.
    if d.nil?
      create_ship_request_devlog
      d = devlogs.where(user_id: nil, ship_request: self).order(:created_at).first
    end

    return unless d

    begin
      formatted_time = if devlogged_seconds.present? && devlogged_seconds.to_i > 0
                         ApplicationController.helpers.format_duration(devlogged_seconds.to_i)
      else
                         "-"
      end

      credits = credits_awarded.present? ? credits_awarded : "-"

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
      TEXT

      d.update_columns(title: title, content: new_content.strip, duration_seconds: devlogged_seconds.to_i)
    rescue => e
      Rails.logger.error "Failed to sync ship request devlog for ShipRequest ##{id}: #{e.message}"
    end

    # Also propagate meaningful changes to an associated Ship (if it exists).
    # e.g. if an admin edits credits_awarded or devlogged_seconds after approval,
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
  def approve!(admin_user:, credits_per_hour: nil, recipient_user_id: nil, multiplier: nil)
    raise "cannot approve non-pending request" unless pending?

    # Compute the devlogged seconds if not already stored
    self.devlogged_seconds = devlogs.sum(:duration_seconds).to_i if devlogged_seconds.blank? || devlogged_seconds.to_i <= 0

    # choose rate priority: explicit param -> request value -> project value
    rate = credits_per_hour.presence || self.credits_per_hour.presence || project.credits_per_hour

    # Find recipient user if supplied (if nil, award to project.user inside Project#award_credits!)
    recipient = User.find_by(id: recipient_user_id) if recipient_user_id.present?

    # ship record will be created via project helper
    # pass multiplier through so ship, notches, and audits can reflect it
    applied_multiplier = multiplier.presence || self.multiplier || 1.0
    ship = project.ship_and_award_credits!(admin_user: admin_user, rate: rate, devlogged_seconds: devlogged_seconds, shipped_at: Time.current, recipient_user: recipient, multiplier: applied_multiplier)

    # record multiplier on the request and (redundantly) ensure ship has it
    self.multiplier = applied_multiplier
    ship.update!(multiplier: applied_multiplier) if ship.has_attribute?(:multiplier)

    # Link the request directly to the created Ship so future updates can operate on the same row.
    update!(status: "approved", approved_at: Time.current, processed_by: admin_user, credits_awarded: ship.credits_awarded, devlogged_seconds: ship.devlogged_seconds, ship_id: ship.id, multiplier: applied_multiplier)

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
  def propagate_changes_to_ship
    ship = associated_ship
    return unless ship

    attrs = {}
    if saved_change_to_credits_awarded?
      attrs[:credits_awarded] = credits_awarded.to_f
    end

    if saved_change_to_devlogged_seconds?
      attrs[:devlogged_seconds] = devlogged_seconds.to_i
    end

    if saved_change_to_multiplier?
      attrs[:multiplier] = multiplier.to_f
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
end
