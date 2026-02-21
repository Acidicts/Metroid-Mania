class User < ApplicationRecord
  # When a user is deleted we nullify references and reassign them to the system user
  has_many :projects, dependent: :nullify
  # Active (non-deleted) projects owned by this user
  has_many :active_projects, -> { where(deleted_at: nil) }, class_name: "Project"
  has_many :orders, dependent: :nullify
  has_many :ships, dependent: :nullify
  has_many :ship_requests, dependent: :nullify
  has_many :assets_projects, dependent: :nullify
  has_many :assets_items, dependent: :nullify
  has_many :charm_slots, dependent: :nullify
  has_many :charm_notches, dependent: :nullify

  # Toggle for whether user sees custom fonts in the UI (DB-backed boolean column)
  attribute :font_on, :boolean, default: true
  attribute :hackatime_trust_status, :string
  attribute :region, :string
  # Store how many charm slots a user has; defaults to zero so new users start with none
  attribute :charm_slots, :integer, default: 0

  enum :role, { user: 0, admin: 1, superadmin: 2 }, default: :user

  # Scope to exclude the system placeholder user
  scope :not_system, -> { where.not(provider: "system", uid: "deleted_user") }

  # Allow optional password for OAuth users. Use has_secure_password without validations
  # and manage presence checks if needed elsewhere.
  has_secure_password validations: false

  has_many :audits, dependent: :nullify

  validates :uid, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :charm_slots, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :is_superadmin, on: :update

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.name = auth.info.name
      user.email = auth.info.email
      user.slack_id = auth.info.slack_id
      user.verification_status = auth.info.verification_status
      # Set admin role if the auth provider says so (and we trust it)
      # user.role = :admin if auth.info.admin
      user.role ||= :user # Default role
    end
  end

  # The number of notches that are available for use.  Notches always
  # belong to a `CharmSlot`, but a slot may be tied to an order (meaning the
  # notch has already been spent).  Free notches are therefore those associated
  # with slots that have no order.
  def free_notches
    CharmNotch.where(user_id: id, charm_slot_id: nil).count
  end

  # Adjust the number of *free* (unassigned) charm notches the user has.  The
  # admin UI allows an integer value to be supplied, and setting a target value
  # should create or delete unlinked `CharmNotch` records accordingly.  The
  # method operates purely on records where `charm_slot_id` is `nil` (notches
  # already assigned to slots are untouched).  Negative targets are not
  # permitted and will raise `ArgumentError` so callers can propagate an error
  # message back to the form if necessary.
  def adjust_charm_notches!(target)
    # coerce numeric-ish values to integer; decimals/drop fractions silently
    target = target.to_f.to_i
    if target < 0
      raise ArgumentError, "desired charm notches must be >= 0"
    end

    current = free_notches
    return if target == current

    if target > current
      # add new free notches; each notch needs a slot with no order.  To keep
      # things simple we create a fresh slot for each notch.  Any existing free
      # slots are ignored because there's no capacity concept.
      (target - current).times do
        slot = charm_slots.create!
        charm_notches.create!(charm_slot: nil)
      end
    else
      # remove excess *free* (unlinked) notches first.  The public API of this
      # method promises to operate only on unassigned records, so there's no need
      # to touch notches already bound to a slot.
      to_remove = current - target
      removable = CharmNotch.where(user_id: id, charm_slot_id: nil).limit(to_remove)
      removable.destroy_all

      # clean up any empty slots that no longer have notches and are unassigned
      CharmSlot.where(user_id: id, order_id: nil)
               .left_joins(:charm_notches)
               .where(charm_notches: { id: nil })
               .destroy_all
    end
  end

  def set_region_from_ip(ip)
    return nil unless ip.present?

    region = HackclubIpService.new(ip: ip).get_region_by_ip
    return nil if region.nil?

    # Persist the region immediately without running validations so login isn't blocked
    if region != self.region
      update_column(:region, region)
    end

    region
  end

  def admin?
    self.role == "admin" || self.superadmin?
  end

  # Is this user the superadmin defined by environment?
  def superadmin?
    if self.role == "superadmin" or self.role == 2
      true
    else
      false
      is_superadmin
    end
  end

  def is_superadmin
    env_uid = ENV["SUPERADMIN_UID"]
    env_email = ENV["SUPERADMIN_EMAIL"]&.downcase
    if (env_uid.present? && uid == env_uid) || (env_email.present? && email&.downcase == env_email)
      self.role = 2
      true
    else
      false
    end
  end

  # Display name for the user (falls back to email or name)
  def display_name
    name.presence || email.presence || "User #{id}"
  end

  # System placeholder user used to own records of deleted users. Created lazily.
  def self.system_user
    find_or_create_by!(provider: "system", uid: "deleted_user") do |u|
      u.email = "deleted@example.com"
      u.name = "Deleted User"
      u.password = SecureRandom.hex(16)
      u.role = :user
    end
  end

  def system_user?
    provider == "system" && uid == "deleted_user"
  end

  before_destroy do
    if system_user?
      # Prevent accidental removal of the placeholder
      throw(:abort)
    end
  end

  # Reassign direct children to the system user before destruction so they are not destroyed
  # by dependent callbacks or left NULL. This ensures records always have an owner.
  def destroy
    return false if system_user?

    sys = User.system_user
    Project.where(user_id: id).update_all(user_id: sys.id)
    Order.where(user_id: id).update_all(user_id: sys.id)
    Ship.where(user_id: id).update_all(user_id: sys.id)
    AssetsProject.where(user_id: id).update_all(user_id: sys.id)
    ShipRequest.where(user_id: id).update_all(user_id: sys.id)
    ShipRequest.where(processed_by_id: id).update_all(processed_by_id: sys.id)
    Audit.where(user_id: id).update_all(user_id: sys.id)

    super
  end

  # Anonymize this user and their projects instead of destructive deletion.
  # This replaces personal data with generic placeholders and reassigns ownership
  # of dependent records to the system user. Returns true when successful.
  def anonymize!
    return false if system_user? || superadmin?

    sys = User.system_user

    transaction do
      # Anonymize projects owned by this user and transfer ownership to system user.
      # Use `save(validate: false)` to avoid model validations (e.g. required repo URL) that would block anonymization.
      projects.find_each do |p|
        p.assign_attributes(name: "Deleted Project", description: nil, repository_url: nil, readme_url: nil, user_id: sys.id)
        p.save!(validate: false)
      end

      # Reassign other dependent records to system user (orders, ships, ship_requests, audits)
      Order.where(user_id: id).update_all(user_id: sys.id)
      AssetsProject.where(user_id: id).update_all(user_id: sys.id)
      Ship.where(user_id: id).update_all(user_id: sys.id)
      ShipRequest.where(user_id: id).update_all(user_id: sys.id)
      ShipRequest.where(processed_by_id: id).update_all(processed_by_id: sys.id)
      Audit.where(user_id: id).update_all(user_id: sys.id)

      # Overwrite personal fields on this user with anonymized values
      anonymized_email = "deleted_user_#{id}@example.invalid"
      update!(name: "Deleted User", email: anonymized_email, slack_id: nil, uid: "deleted_user_#{id}_#{SecureRandom.hex(6)}", provider: "deleted", password: SecureRandom.hex(16))
    end

    true
  end

  # Recalculate the amount the user has spent on Orders (sum of non-denied orders) and persist it.
  # Returns the computed amount (float).
  def recalculate_amount_spent!
    total = orders.where.not(status: "denied").sum(:cost).to_f
    update!(amount_spent: total)
    total
  end

  # Sum of credits_awarded across all ships for active (non-deleted) projects owned by this user.
  def total_shipped_credits
    Ship.joins(:project).where(projects: { user_id: id, deleted_at: nil }).sum(:credits_awarded).to_f
  end

  # Canonical total credits = ships total + admin-set offset, always rounded up.
  # credit_offset is set by an admin to raise/lower the total to a target value.
  def total_credits
    (total_shipped_credits + (credit_offset || 0.0)).ceil
  end

  # Available balance = total_credits - amount already spent on orders, always rounded up.
  def available_balance
    (total_credits - (amount_spent || 0.0)).ceil
  end

  # Recalculate and persist the user's currency to be total_credits minus amount_spent.
  # Incorporates credit_offset so currency always reflects "earned + offset - spent".
  # Returns the computed currency value (float).
  def recalculate_currency!
    new_currency = available_balance
    update!(currency: new_currency)
    new_currency
  end

  # Ensure the number of associated CharmSlot records matches the integer stored
  # in the `charm_slots` column.  This callback runs every time a user is loaded
  # from the database (after_find) so that changes made by admins or migration
  # backfills will automatically create any missing slots the next time the
  # user record is fetched.  Excess records are left alone.
  after_find :ensure_charm_slots_match_attribute

  def ensure_charm_slots_match_attribute
    desired = read_attribute(:charm_slots).to_i
    current = charm_slots.size
    return if desired <= current

    missing = desired - current

    # Any slot must point at an Order.  We'll use a single placeholder product
    # that has no cost or inventory; the precise values are unimportant, as orders
    # pointing at this product will always have cost 0 and never correspond to a real
    # shop item.  Because the product model validates that `credits_per_dollar` is
    # greater than zero, create or update the placeholder while skipping validations
    # so we don't run into errors when the app loads during boot or in tests.
    placeholder = Product.find_or_initialize_by(name: "Charm slot placeholder")
    placeholder.stock = 0
    placeholder.limited = false
    placeholder.price_currency = 0.0
    # leave credits_per_dollar nil so validation allows it
    placeholder.save!(validate: false) if placeholder.new_record? || placeholder.changed?

    transaction do
      missing.times do
        # create an empty slot with no order; order can be added later when the
        # user buys/assigns something.
        charm_slots.create!
      end
    end
  end

  # Sync Hackatime trust status for this user and persist it to the DB.
  # Returns the humanized status string (or nil) and updates `hackatime_synced_at`.
  def sync_hackatime_status!
    return unless slack_id.present?

    service_result = HackatimeService.new(slack_id: slack_id).get_trusted_status

    # Service may return a Hash { trust_level:, trust_value: } or a scalar. Normalize accordingly.
    raw = if service_result.is_a?(Hash)
      # Prefer numeric trust_value when present, otherwise trust_level string
      service_result[:trust_value] || service_result["trust_value"] || service_result[:trust_level] || service_result["trust_level"]
    else
      service_result
    end

    # Store canonical (machine-friendly) status strings in DB: "verified", "needs_submission", "unverified"
    canonical = case raw
    when "verified", :verified, 2
      "verified"
    when "needs_submission", "needs submission", :needs_submission, 1
      "needs_submission"
    when "unverified", "blue", :unverified, 0
      "unverified"
    else
      raw.nil? ? nil : raw.to_s.downcase.tr(" ", "_")
    end

    update!(hackatime_trust_status: canonical, hackatime_synced_at: Time.current)
  end

  # Sync Hackatime project totals for this user's projects.
  # Fetches stats once and updates owned projects that have hackatime_ids.
  def sync_hackatime_projects!
    return unless slack_id.present?

    service = HackatimeService.new(slack_id: slack_id)
    stats = service.get_projects
    return unless stats && stats.any?

    owned_projects = projects.where.not(hackatime_ids: [ nil, "" ]).where(deleted_at: nil)
    owned_projects.find_each do |proj|
      total = proj.hackatime_targets.sum { |t| stats[t].to_i }
      prior = proj.total_seconds.to_i
      if prior != total
        proj.update!(total_seconds: total)
        Rails.logger.info "sync_hackatime_projects!: updated project_id=#{proj.id} for user_id=#{id} from #{prior} to #{total}"
      end
    end
  end

  private
end
