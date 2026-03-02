class Ship < ApplicationRecord
  belongs_to :project, counter_cache: true
  belongs_to :user

  # charm notches earned via shipping belong to the ship; when a ship is deleted
  # we nullify the association so orphaned notches can be cleaned up by
  # `User#reconcile_charm_notches!` rather than being destroyed outright.
  has_many :charm_notches, dependent: :nullify

  # when a ship is removed (e.g. during test setup) we should also remove
  # any associated comments; otherwise SQLite complains with foreign key
  # constraint failures.  Devlogs already handle this, but ships were missing the
  # dependency.
  has_many :comments, dependent: :destroy

  validates :devlogged_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :credits_awarded, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # multiplier copied from the associated ShipRequest at approval time.  The
  # column is optional; nil means there was no bonus active.
  validates :multiplier, numericality: { greater_than: 0 }, allow_nil: true

  before_create :snapshot_hackatime_ids
  after_create :touch_project_status
  after_create :associate_pending_request
  # notch adjustment should run any time multiplier is changed
  after_update_commit :adjust_notches_for_multiplier
  after_destroy :touch_project_status

  # Accessor helpers for hackatime_ids_snapshot (YAML serialization)
  def hackatime_ids_snapshot
    raw = read_attribute(:hackatime_ids_snapshot)
    return [] if raw.nil? || raw == ""
    return raw if raw.is_a?(Array)

    begin
      YAML.safe_load(raw) || []
    rescue
      raw.to_s.split(",").map(&:strip)
    end
  end

  def hackatime_ids_snapshot=(vals)
    write_attribute(:hackatime_ids_snapshot, vals.present? ? vals.to_yaml : nil)
  end

  private

  def snapshot_hackatime_ids
    self.hackatime_ids_snapshot = project&.hackatime_ids
  end

  # ensure multiplier defaults to 1.0 for new records only so that
  # loading existing ships with a nil multiplier (e.g. pre-migration data)
  # doesn't accidentally mask the fact that the column is blank.
  after_initialize do
    if new_record? && has_attribute?(:multiplier)
      self.multiplier ||= 1.0
    end
  end

  def touch_project_status
    project.recalculate_status! if project.present?
  end

  # If there is a pending ShipRequest that matches this ship (requested before shipped_at),
  # update the request to 'approved' and set credits_awarded so the UI reflects the ship.
  def associate_pending_request
    return unless project.present? && shipped_at.present?

    req = project.ship_requests.where(status: "pending").where("requested_at <= ?", shipped_at).order(requested_at: :desc).first
    return unless req

    begin
      req.update!(status: "approved", approved_at: shipped_at, processed_by: user, credits_awarded: credits_awarded, devlogged_seconds: (devlogged_seconds || req.devlogged_seconds))
      Audit.create!(user: user, project: project, action: "approve_via_ship", details: { ship_id: id, ship_request_id: req.id, credits_awarded: credits_awarded })
    rescue => e
      Rails.logger.error("associate_pending_request failed for Ship #{id}: #{e.message}")
    end
  end



  # Returns true when this Ship's recorded seconds cannot be fully explained by
  # user-created devlogs up to the ship time — indicating external time (e.g. Hackatime)
  # was used to satisfy the shipped seconds. This is used to prevent unlinking
  # linked Hackatime projects that were relied upon when awarding credits.
  public

  def used_hackatime_time?
    return false if devlogged_seconds.blank? || shipped_at.blank? || project.nil?

    # Sum of user-created devlogs up to the shipped_at timestamp
    logged = project.devlogs.where.not(user_id: nil).where("created_at <= ?", shipped_at).sum(:duration_seconds).to_i
    devlogged_seconds.to_i > logged
  end

  # Public convenience: re-sync ship attributes from any matching request.
  # This mirrors logic in ShipRequest#propagate_changes_to_ship but is easier
  # to call from the console on a Ship instance.
  def sync_ship_from_request
    return unless project.present? && shipped_at.present?

    req = project.ship_requests.find_by(ship_id: id)
    req ||= project.ship_requests.where("requested_at <= ?", shipped_at).order(requested_at: :desc).first
    return unless req

    begin
      update_attrs = {}
      if req.multiplier.present? && has_attribute?(:multiplier)
        update_attrs[:multiplier] = req.multiplier.to_f
      end
      if req.credits_awarded.present?
        update_attrs[:credits_awarded] = req.credits_awarded.to_f
      end
      if req.devlogged_seconds.present?
        update_attrs[:devlogged_seconds] = req.devlogged_seconds.to_i
      end

      update!(update_attrs) if update_attrs.any?
      adjust_notches_for_multiplier
    rescue => e
      Rails.logger.error("sync_ship_from_request failed for Ship ##{id}: #{e.message}")
    end
  end

  # When a ship's multiplier is modified, ensure associated charm notches reflect
  # the new multiplier ratio.  This method is invoked after commit so that the
  # existing charm_notches association is up-to-date.
  # Adjust charm notches to match the current multiplier.
  #
  # When called as a callback after updating the ship, we only act if the
  # multiplier actually changed (`saved_change_to_multiplier?`).  External
  # callers (like the backfill rake task) can force recalculation by passing
  # `force: true`.
  def adjust_notches_for_multiplier(force: false)
    return unless force || saved_change_to_multiplier?

    # determine new multiplier value; if called via callback the change
    # details are available, otherwise just use the current value.
    old_multi, new_multi = saved_change_to_multiplier || [ nil, multiplier ]
    return if new_multi.to_f <= 0

    base_notches = credits_awarded.to_f.to_i
    expected = (base_notches * new_multi.to_f).to_i
    current = charm_notches.count
    delta = expected - current

    if delta > 0
      # add additional notches to match new multiplier; assign them to the same
      # user as existing notches if possible, otherwise fall back to project owner
      target_user = charm_notches.first&.user || project.user
      delta.times do
        CharmNotch.create!(user: target_user, charm_slot: nil, ship: self)
      end
    elsif delta < 0
      # remove excess notches, prefer non-admin_granted ones
      to_remove = charm_notches.where(admin_granted: false).order(:id).limit(-delta)
      if to_remove.count < -delta
        # remove additional ones regardless of admin flag if still short
        extra = charm_notches.order(:id).limit((-delta) - to_remove.count)
        to_remove = to_remove + extra
      end
      to_remove.each(&:destroy)
    end
  rescue => e
    Rails.logger.error("Failed to adjust notches for Ship ##{id} after multiplier change: #{e.message}")
  end
end
