require "securerandom"

class Order < ApplicationRecord
  belongs_to :user
  belongs_to :product

  has_one :charm_slot, dependent: :nullify, inverse_of: :order

  # Optional image used when an order represents a custom "charm" purchase.  This allows
  # callers (typically from the storefront or admin UI) to attach a specific URL which is
  # then displayed in user-facing areas such as the charm slot grid.  It is intentionally
  # optional so existing orders continue working and the product's normal
  # `image_url` can still be used as a fallback.
  attribute :charm_image_url, :string

  validates :charm_image_url,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                      message: "must be a valid URL" },
            allow_blank: true

  # Ensure the order has a sane default status before any other work runs.
  #
  # Historically this method also removed notches, but that logic has been
  # moved to an after_commit hook so that it only runs once (and never during a
  # rolled-back transaction).  The old name accumulated some cruft over time,
  # so rename the callback to reflect its current responsibility.
  before_create :set_default_status
  before_validation :set_public_id, on: :create

  validates :public_id, presence: true, uniqueness: true, allow_nil: false, on: :create

  def set_public_id
    # Ensure the public identifier is set to a unique value like "!a1B2c3"
    return if public_id.present?

    loop do
      candidate = "!#{SecureRandom.alphanumeric(6)}"
      unless self.class.where(public_id: candidate).exists?
        self.public_id = candidate
        break
      end
    end
  end

  # Overhaul uses charm notches instead of credits, so validate against user's currency but display free notches on the leaderboard.
  # validate :user_has_enough_currency, on: :create, if: -> { status.blank? || status == "pending" }
  #
  validate :user_denied_is_denied, if: -> { status == "user_denied" }, on: :update
  validate :user_has_enough_free_notches, on: :create, if: -> { status.blank? || status == "pending" }
  # Prevent duplicate pending orders at model level (best-effort; DB unique index is authoritative)
  validates :product_id, uniqueness: { scope: [ :user_id, :status ], message: "already has a pending order" }, if: -> { status == "pending" }

  # canonical mapping used by migration/tests/views
  STATUS_VALUE_MAP = {
    "pending"     => 0,
    "denied"      => 1,
    "shipped"     => 2,
    "user_denied" => 3,
    "submitted"   => 4
  }.freeze

  # Select-friendly array (used by views)
  STATUSES = STATUS_VALUE_MAP.keys.map { |k| [ k.humanize, k ] }.freeze unless const_defined?(:STATUSES)

  # Prefer an integer-backed enum when the DB column is integer.
  # Fall back to a string-backed compatibility layer while migrating.
  begin
    db_has_orders = (ActiveRecord::Base.connection.data_source_exists?("orders") rescue false)
    status_col = (columns_hash["status"] rescue nil)
    if db_has_orders && status_col && status_col.type == :integer
      enum :status, STATUS_VALUE_MAP.transform_keys(&:to_sym)

      # Normalize human-friendly enum keys into the DB-backed integer before validation so
      # callers may pass either a key ('denied') or a numeric/string DB value ('1'/'1').
      before_validation do
        if self.status.present? && self.status.to_s =~ /\A[a-z_]+\z/i
          mapped = self.class.statuses[self.status.to_s]
          self.status = mapped if mapped
        end
      end
    else
      raise "string_status"
    end
  rescue => _ignored
    # string-backed compatibility: provide predicates/scopes/setter/getter expected by app code
    # Be defensive: the DB column *may* be integer-backed even if the enum couldn't be defined
    # at class-eval time (test environments, load-order issues). Handle both numeric and
    # human-friendly representations so predicates and audits remain stable.
    STATUS_VALUE_MAP.keys.each do |s|
      define_method("#{s}?") do
        v = read_attribute(:status)
        # match canonical string or numeric DB value
        v.to_s == s || (v.to_i.to_s == v.to_s && v.to_i == STATUS_VALUE_MAP[s])
      end

      scope s.to_sym, -> {
        where("status = ? OR status = ?", s, STATUS_VALUE_MAP[s])
      }
    end


    def status
      v = read_attribute(:status)
      # if stored as numeric, translate to canonical key
      if v.is_a?(Integer) || v.to_s =~ /\A\d+\z/
        STATUS_VALUE_MAP.invert[v.to_i].to_s
      else
        v.to_s
      end
    end

    def status=(val)
      # accept either numeric or human key and persist the appropriate representation
      if val.is_a?(Integer) || val.to_s =~ /\A\d+\z/
        write_attribute(:status, val.to_i)
      else
        # If we know the canonical mapping, store the integer DB value when possible to avoid
        # writing a human key into an integer column (which some DBs coerce to 0).
        if self.class.const_defined?(:STATUS_VALUE_MAP) && STATUS_VALUE_MAP[val.to_s]
          write_attribute(:status, STATUS_VALUE_MAP[val.to_s])
        else
          write_attribute(:status, val.to_s)
        end
      end
    end
  end

  def user_denied_is_denied
    unless status == "user_denied"
      errors.add(:status, "can only be set to 'user_denied'")
    end
    charm_slot_temp = self.charm_slot
    charm_slot_temp&.update(order: nil)
    charm_slot_temp&.charm_notches&.update_all(charm_slot_id: nil)
  end

  # Stable array used by views/forms — do not build this by calling other class methods at class-eval time.
  # STATUSES = [
  #   ['Pending',    'pending'],
  #   ['Paid',       'paid'],
  #   ['Unshipped',  'unshipped'],
  #   ['Shipped',    'shipped'],
  #   ['Denied',     'denied'],
  #   ['Refunded',   'refunded']
  # ].freeze unless const_defined?(:STATUSES)

  # Runtime-safe accessor for select helpers. Only calls `statuses` if it's a zero-arity method
  # (protects against methods that require arguments and triggered the ArgumentError).
  def self.statuses_for_select
    STATUSES
  end

  def ensure_correct_number_of_notches_used
    return unless charm_slot

    required = product.notch_cost.to_i
    assigned = CharmNotch.where(user_id: user_id, charm_slot_id: charm_slot_id).count

    if assigned != required
      if assigned < required
        CharmNotch.where(user_id: user_id, charm_slot_id: nil).limit(required - assigned).update_all(charm_slot_id: charm_slot_id)
      else
        CharmNotch.where(user_id: user_id, charm_slot_id: charm_slot_id).limit(assigned - required).update_all(charm_slot_id: nil)
      end
    end
  end

  def user_has_enough_free_notches
    return if product.blank?

    required = product.notch_cost

    if user.free_notches < required
      errors.add(:base, "Insufficient free notches")
    end
  end

  # Return the image that should be shown for this order when it is rendered in contexts
  # such as a charm slot.  Prefer the explicitly-set `charm_image_url` attribute but fall
  # back to the associated product's image if one exists.  This keeps display logic in the
  # model and lets views stay simple.
  def charm_image_url_for_display
    charm_image_url.presence || product&.image_url
  end

  # If an order ever becomes `denied` through a code path that didn't refund the user,
  # attempt to refund here (idempotent: skip if an `order_refunded` audit already exists).
  after_update_commit :refund_if_denied, if: -> { saved_change_to_status? }

  # Deduct the user's free notches when the order is successfully committed
  # to the database.  Using `after_commit` prevents the common bug where a
  # nested or premature insert would fire the callback and then be rolled back
  # later, leaving the user charged twice.  The `on: :create` option ensures
  # the logic only runs once for the initial insert.
  after_commit :deduct_notches_after_create, on: :create

  private

  # `before_create` hook moved to a more descriptive name; kept as a
  # separate method for clarity and to avoid surprising side effects when the
  # callback list is inspected.
  def set_default_status
    # Set a default status before the record is saved (validation and the
    # after_commit deduction callback both rely on status == "pending").
    self.status ||= "pending"
  end

  def deduct_notches_after_create
    # Only charge when the order still looks like a real purchase.  If the
    # status has been changed out from under us (or the product has no cost),
    # there's nothing to do.
    return unless status == "pending"
    return unless product.notch_cost.present? && product.notch_cost.to_i > 0

    # Guard against races: acquire a row-level lock on the user so two orders
    # can't examine the old free_notches value at the same time.  If the lock
    # is already held by another transaction the current thread will wait until
    # it commits, ensuring we always operate on a stable counter.
    user.with_lock do
      # reload user associations now that we have the lock
      user.reload

      required = product.notch_cost.to_i
      if required > user.free_notches
        # If the cost has changed or another order drained the account while
        # we were waiting, gracefully abort rather than raising an exception.
        Rails.logger.warn("Order #{id} not charged: insufficient free notches after lock")
        # mark the order denied so the UI can surface the failure
        update!(status: "denied") if status == "pending"
        return
      end

      slot = charm_slot || create_charm_slot!(user: user)

      user_notches = user.charm_notches
                         .where(charm_slot_id: nil)
                         .limit(required)
      if user_notches.size != required
        Rails.logger.warn("Expected to deduct #{required} notches for order #{id} but found #{user_notches.size}")
      end
      user_notches.each { |n| n.update!(charm_slot: slot) }
    end
  end

  # Ensure user has sufficient funds for this order at creation time.
  def user_has_enough_currency
    return if product.blank?

    required = if product.variable_grant?
      if grant_amount_cents.present?
        product.credits_for_dollars(grant_amount_cents.to_f / 100.0).to_f
      else
        # If no grant amount provided, assume min allowed
        product.credits_for_dollars((product.grant_min_cents || Product::DEFAULT_MIN_GRANT_CENTS) / 100.0).to_f
      end
    else
      product.cost_in_credits.to_f
    end

    # Historically we compared against available_balance, which is derived from
    # shipped credits and amount_spent. In tests (and some maintenance scripts) we
    # often set `user.currency` directly, and the UI/checkout flow trusts the
    # currency value more than the derived balance.  Using only
    # available_balance caused spurious "Insufficient funds" errors when the
    # two values diverged.  Use whichever balance is larger to avoid rejecting a
    # valid purchase, and normalize to a float for comparison.
    current_balance = [ user.currency.to_f, user.available_balance.to_f ].max

    if current_balance < required
      errors.add(:base, "Insufficient funds")
    end
  end

  validate :grant_amount_valid_for_product

  def grant_amount_valid_for_product
    return if product.blank? || !product.variable_grant?

    if grant_amount_cents.nil?
      errors.add(:grant_amount_cents, "must be provided for variable products")
      return
    end

    min = product.grant_min_cents || Product::DEFAULT_MIN_GRANT_CENTS
    max = product.grant_max_cents || Product::DEFAULT_MAX_GRANT_CENTS

    unless grant_amount_cents >= min && grant_amount_cents <= max
      errors.add(:grant_amount_cents, "must be between $#{'%.2f' % (min / 100.0)} and $#{'%.2f' % (max / 100.0)}")
    end
  end

  # Refunds the user when an order transitions to `denied` unless a refund was already recorded.
  def refund_if_denied
    prev_status, new_status = saved_change_to_status
    return unless new_status == "denied" && prev_status != "denied"
    return unless cost.present? && cost.to_f > 0

    # If an explicit refund audit exists for this order, assume refund already happened.
    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
    refund_exists = if adapter.include?("sqlite")
      # sqlite: use json_extract
      Audit.where("action = ? AND json_extract(details, '$.order_id') = ?", "order_refunded", id.to_s).exists?
    else
      # postgres and others: use jsonb operator and cast
      Audit.where("action = ? AND (details ->> 'order_id')::text = ?", "order_refunded", id.to_s).exists?
    end

    # Fallback: some environments may serialize JSON slightly differently — do an in-memory check as a last resort.
    unless refund_exists
      refund_exists = Audit.where(action: "order_refunded").to_a.any? { |a| a.details && a.details["order_id"].to_i == id }
    end

    return if refund_exists

    user.update!(currency: (user.currency || 0) + cost.to_f, amount_spent: (user.amount_spent || 0).to_f - cost.to_f)

    # Use a real user for the audit entry (prefer an admin if available, otherwise fall back to any user).
    audit_user = User.find_by(role: :admin) || User.first

    # Store a canonical status string in the audit (handle integer-backed enums or legacy string columns).
    canonical_prev = if self.class.respond_to?(:statuses)
      if prev_status.is_a?(Integer) || prev_status.to_s =~ /\A\d+\z/
        self.class.statuses.key(prev_status.to_i).to_s rescue prev_status.to_s
      else
        prev_status.to_s
      end
    else
      prev_status.to_s
    end

    Audit.create!(user: audit_user, project: nil, action: "order_refunded", details: { order_id: id, order_public_id: public_id, amount: cost.to_f, previous_status: canonical_prev })
  end

  public

  # to_param uses public_id for friendlier public URLs when present
  def to_param
    public_id.present? ? public_id : id.to_s
  end

  # Find an order by either numeric id or the public_id (e.g., '!a1B2c3')
  def self.find_by_param(param)
    return find(param) unless param.to_s.start_with?("!")
    find_by!(public_id: param.to_s)
  end

  # Backwards-compatible predicate aliases for previous misspellings / synonyms
  def fulfilled?
    respond_to?(:status) ? (status.to_s == "shipped" || status.to_s == "fulfilled") : false
  end

  def fufilled?
    fulfilled?
  end

  # Human-readable name for display (e.g., "Product Name - $ 12.34")
  def name
    usd = if price_usd.present?
      price_usd.to_f
    elsif product && product.variable_grant?
      if grant_amount_cents.present?
        grant_amount_cents.to_f / 100.0
      elsif product.grant_amount_cents.present?
        product.grant_amount_cents.to_f / 100.0
      else
        (product.grant_min_cents || Product::DEFAULT_MIN_GRANT_CENTS).to_f / 100.0
      end
    else
      product&.price_currency.to_f
    end

    "#{product&.name} - $ #{'%.2f' % usd}"
  end
end
