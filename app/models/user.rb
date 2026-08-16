# == Schema Information
#
# Table name: users
#
#  id                      :bigint           not null, primary key
#  amount_spent            :float            default: 0.0, not null
#  charm_slots             :integer          default: 0, not null
#  created_at              :datetime         not null
#  credit_offset           :float            default: 0.0, not null
#  currency                :float
#  default_address_id      :string
#  email                   :string
#  flagged_for_fraud       :boolean          default: false, not null
#  flagged_for_fraud_by_id :integer
#  font_on                 :boolean          default: true, not null
#  fraud_reason            :string
#  hackatime_api_key       :string
#  hackatime_synced_at     :datetime
#  hackatime_trust_status  :string
#  nda                     :boolean
#  name                    :string
#  password_digest         :string
#  provider                :string
#  region                  :string
#  role                    :integer
#  set_region              :string
#  setup                   :boolean          default: false, not null
#  slack_id                :string
#  uid                     :string
#  updated_at              :datetime         not null
#  username                :string
#  verification_status     :string
#  xp                      :integer          default: 0, not null
#
# Indexes
#  index_users_on_flagged_for_fraud_by_id  (flagged_for_fraud_by_id)
#  index_users_on_hackatime_trust_status   (hackatime_trust_status)
#  index_users_on_slack_id                 (slack_id)
#  index_users_on_uid                      (uid)
#
class User < ApplicationRecord
  CACHE_TTL = 1.hour

  # When a user is deleted we nullify references and reassign them to the system user
  has_many :projects, dependent: :nullify
  # Active (non-deleted) projects owned by this user
  has_many :active_projects, -> { where(deleted_at: nil) }, class_name: "Project"
  has_many :orders, dependent: :nullify
  # history of devlog entries authored by the user (not all records have a
  # user due to legacy/system-generated devlogs)
  has_many :devlogs, dependent: :nullify
  has_many :ships, dependent: :nullify
  has_many :ship_requests, dependent: :nullify
  has_many :assets_projects, dependent: :nullify
  has_many :assets_items, dependent: :nullify
  has_many :charm_slots, dependent: :nullify
  has_many :charm_notches, dependent: :nullify
  has_many :user_achievements, dependent: :destroy
  has_many :achievements, through: :user_achievements

  has_many :sessions, dependent: :destroy

  # likes the user has made on projects
  has_many :user_likes, dependent: :destroy
  has_many :liked_projects, through: :user_likes, source: :project

  # every user owns a single wishlist.  We create one automatically so callers
  # can safely call `current_user.wishlist` without guarding for nil.
  has_one :wishlist, dependent: :destroy

  after_create :ensure_wishlist
  after_commit :invalidate_user_cache

  # Toggle for whether user sees custom fonts in the UI (DB-backed boolean column)
  attribute :font_on, :boolean, default: true
  attribute :hackatime_trust_status, :string

  attribute :hca_id, default: ""
  attribute :nda, default: false
  attribute :default_address_id, default: ""

  attribute :username, default: ""

  # Region
  REGIONS = [
    "United States",
    "United Kingdom",
    "India",
    "Canada",
    "Australia",
    "EU",
    "Rest of the World"
  ].freeze

  attribute :region, :string
  attribute :set_region, :string

  # Store how many charm slots a user has; defaults to zero so new users start with none
  attribute :charm_slots, :integer, default: 0
  attribute :xp, :integer, default: 0

  enum :role, { user: 0, admin: 1, superadmin: 2 }, default: :user

  # if an admin marks someone as fraudulent, we record who did it for auditing
  belongs_to :flagged_for_fraud_by, class_name: "User", optional: true
  attribute :fraud_reason, :string, default: nil

  validate :ensure_fraud_reason, on: :update
  validate :get_xp

  validate :ensure_username

  def ensure_username
    if username.blank?
      self.setup = false
      save(validate: false)
    end
  end

  def get_xp
    # XP is based on the amount of time the user themself has documented
    # on projects they own. Devlogs authored by other users on the same
    # project should not contribute to this user's XP.
    xp_minutes = projects.inject(0) do |sum, project|
      sum + project.devlogs.where(user_id: id).sum(:duration_seconds).to_i / 60
    end

    # Persist the computed value so other code can rely on the `xp` column.
    self.xp = xp_minutes
    xp_minutes
  end

  def get_level
    xp = self.xp.to_i
    lvl = 1

    while xp >= lvl * 100
      xp -= lvl * 100
      lvl += 1
    end

    # return [current_level, xp_into_this_level]
    [ lvl, xp ]
  end

  def not_liked_project(project_id)
    !liked_projects.exists?(project_id) && Project.exists?(project_id) && (Project.find(project_id).user_id != self.id)
  end

  # convenience accessor for display
  def flagged_for_fraud_by_name
    flagged_for_fraud_by&.name
  end

  def has_streak
    devlogs = Devlog.where(user_id: self.id)
    streak = 0
    current_date = Date.current
    while devlogs.where("created_at >= ? AND created_at < ?", current_date.beginning_of_day, current_date.end_of_day).exists?
      streak += 1
      current_date -= 1.day
    end
    streak
  end

  def get_level_progress_dec
    lvl, xp_into = get_level
    # compute fraction of current tier completed
    denom = lvl * 100.0
    return 0.0 if denom.zero?

    raw = xp_into.to_f / denom
    rounded = raw.round(2)
    rounded == 1.0 && raw < 1.0 ? raw : rounded
  end

  def flagged_for_fraud?
    flagged_for_fraud
  end

  def ensure_fraud_reason
    if !flagged_for_fraud?
      self.fraud_reason = nil
    end
  end

  # Scope to exclude the system placeholder user
  scope :not_system, -> { where.not(provider: "system", uid: "deleted_user") }

  # Allow optional password for OAuth users. Use has_secure_password without validations
  # and manage presence checks if needed elsewhere.
  has_secure_password validations: false

  has_many :audits, dependent: :nullify

  validates :uid, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :charm_slots, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.from_omniauth(auth)
    # 1. Use first_or_initialize so existing users get updated on every login
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize

    # 2. Assign attributes (auth.info methods work for name, email, slack_id, verification_status)
    user.hca_id              = auth.uid # OIDC 'sub' maps directly to auth.uid
    user.name                = auth.info.name
    user.email               = auth.info.email
    user.slack_id            = auth.info.slack_id
    user.verification_status = auth.info.verification_status

    user.access_token = auth.credentials&.token.to_s

    # 3. Handle optional/HQ attributes safely from raw_info identity nested hash
    if ENV["HQ"]
      identity          = auth.extra&.raw_info&.identity
      user.phone_number = identity&.phone_number
      user.birthdate    = identity&.birthdate
    end

    # 4. Default role for new records
    user.role ||= :user

    # 5. Persist changes
    user.save!
    user
  end

  def self.find_cached(id)
    return nil if id.nil?

    Rails.cache.fetch("user:#{id}", expires_in: CACHE_TTL) { find_by(id: id) }
  end

  def user_charm_notches
    charm_notches.where(user: self)
  end

  # override accessor so that a nil association will be replaced with a new
  # record.  This mirrors the behaviour of `ensure_wishlist` and keeps view
  # conditionals simple.
  def wishlist
    super || create_wishlist
  end

  def charm_slots_orders
    slots = self.charm_slots.where.not(order_id: nil)
    orders = []
    for slot in slots
      if slot.order.status == "submitted" || slot.order.status == "fulfilled"
        orders.append(slot.order)
      end
    end
    orders
  end

  def total_devlogged_hours
    devlogs = Devlog.where(user_id: self.id)
    devlogs.sum(&:duration_seconds_total) / 3600.0
  end

  # The number of notches that are available for use.  Notches always
  # belong to a `CharmSlot`, but a slot may be tied to an order (meaning the
  # notch has already been spent).  Free notches are therefore those associated
  # with slots that have no order.
  def free_notches
    CharmNotch.where(user_id: id, charm_slot_id: nil).count
  end

  # Ensure charm notches accurately reflect hours earned by shipped projects.
  # This is triggered when a user views their slots; it will:
  # 1. destroy any notches that are unbound (ship_id nil) or refer to missing ships
  #    *except* those manually granted by an admin (`admin_granted = true`).
  # 2. walk the user's ships in chronological order, converting 2h periods into
  #    one notch each and carrying leftover time forward across ships.
  # 3. add or remove notches (excluding admin-granted records) to match the
  #    computed total.  New notches are attributed to the latest ship.
  #
  # Returns the final desired notch count (excluding admin notches).
  def reconcile_charm_notches!
    # Historically, admin‑granted notches were marked by setting `ship_id = -1`
    # or (after the 2026 migration) `admin_granted = true`.  A common complaint
    # has been that older admin notches began disappearing when users viewed
    # their charm slots because they lacked the new flag.  The reconciliation
    # routine runs on that page, so we take the opportunity here to convert any
    # existing free notches into the new format if we detect a likely admin
    # origin.  The simplest heuristic is: if the user currently has one or more
    # empty charm slots (created automatically when an admin added notches),
    # then every free notch is probably an admin grant and should be preserved.
    # This update runs once per call and is idempotent.
    if charm_slots.where(order_id: nil).exists?
      charm_notches.where(ship_id: nil, admin_granted: false)
                   .update_all(admin_granted: true)
    end

    # step 1: remove orphans
    # remove notches not tied to any existing ship.  Historically admin
    # notches were indicated by ship_id = -1; after the migration we instead
    # mark them with `admin_granted = true`.  Either way they should be
    # preserved here so that administrators can manually grant them without
    # reconciliation wiping them out.  We therefore only destroy records that
    # are *not* admin-granted.
    charm_notches.where(ship_id: nil, admin_granted: false).destroy_all
    charm_notches.where.not(ship_id: -1).where(admin_granted: false)
                 .left_joins(:ship)
                 .where(ships: { id: nil })
                 .destroy_all

    # a user earns notches based on ships made against their projects, not the
    # ships the user themselves created.  Build a scope for those "owned" ships
    # so we can reuse it throughout the algorithm.
    owned_ships = Ship.joins(:project)
                      .where(projects: { user_id: id })
                      .order(:shipped_at)

    carry_hours = 0.0
    desired_by_ship = {}
    owned_ships.each do |s|
      hrs = (s.approved_seconds.to_f / 3600.0) + carry_hours
      count = (hrs / 2.0).floor
      desired_by_ship[s.id] = count
      carry_hours = hrs - count * 2.0
    end

    desired = desired_by_ship.values.sum

    # compare with existing notches (ignoring admin-created records).  In
    # addition to the old ship_id=-1 marker we also skip any row that has the
    # new `admin_granted` flag.
    existing = charm_notches.non_admin.count
    diff = desired - existing

    if diff > 0
      # add missing notches on a per-ship basis.  New notches should never be
      # marked admin_granted because they represent earned hours.
      existing_by_ship = charm_notches.non_admin.group(:ship_id).count
      desired_by_ship.each do |ship_id, target|
        current = existing_by_ship[ship_id] || 0
        to_add = target - current
        if to_add > 0
          # safe to look up within owned_ships, which defined the desired counts
          ship = owned_ships.find { |s| s.id == ship_id }
          to_add.times { charm_notches.create!(ship: ship, charm_slot: nil) }
        end
      end
    elsif diff < 0
      # remove excess notches, preferring most recent ships first so older earned notches stay
      to_remove = -diff
      charm_notches.non_admin
                   .joins(:ship)
                   .order("ships.shipped_at DESC")
                   .limit(to_remove)
                   .destroy_all
    end

    desired
  end

  # Adjust the number of *free* (unassigned) charm notches the user has.  The
  # admin UI allows an integer value to be supplied, and setting a target value
  # should create or delete unlinked `CharmNotch` records accordingly.  The
  # method operates purely on records where `charm_slot_id` is `nil` (notches
  # already assigned to slots are untouched).  Negative targets are not
  # permitted and will raise `ArgumentError` so callers can propagate an error
  # message back to the form if necessary.
  def adjust_charm_notches!(target, admin: false)
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
      # slots are ignored because there's no capacity concept.  When called from
      # the admin UI we mark the created records so they won't be removed later.
      (target - current).times do
        slot = charm_slots.create!
        charm_notches.create!(charm_slot: nil, admin_granted: admin)
      end
    else
      # remove excess *free* (unlinked) notches first.  When this method is
      # triggered by the admin controller we allow deletion of admin-granted
      # records so that the form remains a true "set the total" operation.  In
      # other contexts we leave admin-granted notches untouched.
      to_remove = current - target

      removable_scope = CharmNotch.where(user_id: id, charm_slot_id: nil)
      removable_scope = removable_scope.where(admin_granted: false) unless admin
      removable = removable_scope.limit(to_remove)
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

  # Run user login side effects in one place so controllers can call a single hook.
  # This must never block authentication.
  def on_login!(ip: nil)
    set_region_from_ip(ip)
  rescue => e
    Rails.logger.warn("Failed to run login hook for user #{id}: #{e.message}")
    nil
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
    end
  end

  # Display name for the user (falls back to email or name)
  def display_name
    name.presence || "User #{id}"
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

  # Walk every defined achievement and grant any the user now qualifies for.
  #
  # This method is idempotent and safe to call frequently; the underlying
  # `Achievement#check_and_grant!` will skip already-awarded badges.
  def evaluate_achievements!
    Achievement.find_each { |ach| ach.check_and_grant!(self) }
  end

  before_destroy do
    if system_user?
      # Prevent accidental removal of the placeholder
      throw(:abort)
    end
  end

  def del_sessions
    Session.where(user_id: id).destroy_all
  end

  # Reassign direct children to the system user before destruction so they are not destroyed
  # by dependent callbacks or left NULL. This ensures records always have an owner.
  def destroy
    return false if system_user?

    Session.where(user_id: id).destroy_all

    sys = User.system_user

    [ Project, Order, Devlog, Ship, ShipRequest, AssetsProject, AssetsItem, CharmSlot, CharmNotch, Audit ].each do |model|
      model.where(user_id: id).update_all(user_id: sys.id)
    end

    ShipRequest.where(processed_by_id: id).update_all(processed_by_id: sys.id)

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

  # Recalculate and persist the user's currency to be total_shipped_credits + credit_offset - amount_spent.
  # Returns the computed currency value (float).
  def recalculate_currency!
    new_currency = total_shipped_credits + (credit_offset || 0.0) - (amount_spent || 0.0)
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
    placeholder.show = false
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
    return unless slack_id.present? || email.present?

    service = HackatimeService.new(slack_id: slack_id, email: email)
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

  def invalidate_user_cache
    Rails.cache.delete("user:#{id}")
  end

  # callback used to make sure every user has a wishlist record.  defined
  # here at the end so earlier public methods retain their default visibility.
  def ensure_wishlist
    create_wishlist unless wishlist
  end
end
