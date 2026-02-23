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

  before_create :snapshot_hackatime_ids
  after_create :touch_project_status
  after_create :associate_pending_request
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
end
