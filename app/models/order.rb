class Order < ApplicationRecord
  belongs_to :user
  belongs_to :product

  # Ensure cost is set and balance is deducted when creating an Order (status will be set to `pending`).
  # Set cost when creating; only deduct/validate balance when the order will be `pending`.
  before_create :set_cost_and_deduct_balance

  # Validate balance only when creating an actual pending order (fixtures or manual creates with other statuses should skip)
  # Run balance validation for 'normal' creates (where status isn't explicitly set to a
  # non-pending value). This lets fixtures create historical/non-pending orders without
  # triggering the funds check while ensuring normal creates are validated.
  validate :user_has_enough_currency, on: :create, if: -> { status.blank? || status == 'pending' }
  # Prevent duplicate pending orders at model level (best-effort; DB unique index is authoritative)
  validates :product_id, uniqueness: { scope: [:user_id, :status], message: 'already has a pending order' }, if: -> { status == 'pending' }

  # canonical mapping used by migration/tests/views
  STATUS_VALUE_MAP = {
    'pending'   => 0,
    'denied'    => 1,
    'shipped'   => 2
  }.freeze

  # Select-friendly array (used by views)
  STATUSES = STATUS_VALUE_MAP.keys.map { |k| [k.humanize, k] }.freeze unless const_defined?(:STATUSES)

  # Prefer an integer-backed enum when the DB column is integer.
  # Fall back to a string-backed compatibility layer while migrating.
  begin
    db_has_orders = (ActiveRecord::Base.connection.data_source_exists?('orders') rescue false)
    status_col = (columns_hash['status'] rescue nil)
    if db_has_orders && status_col && status_col.type == :integer
      enum status: STATUS_VALUE_MAP.transform_keys(&:to_sym)

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

  # If an order ever becomes `denied` through a code path that didn't refund the user,
  # attempt to refund here (idempotent: skip if an `order_refunded` audit already exists).
  after_update_commit :refund_if_denied, if: -> { saved_change_to_status? }

  private

  def set_cost_and_deduct_balance
    # Always set cost from product. Only set status/deduct balance for normal creates where
    # status wasn't explicitly provided by the caller (fixtures/tests sometimes create non-pending rows).
    self.cost = product.price_currency
    self.status ||= 'pending'

    # Only deduct balance when creating a real pending order
    if status == 'pending'
      user.update!(currency: user.currency - self.cost)
    end
  end

  # Ensure user has sufficient funds for this order at creation time.
  def user_has_enough_currency
    return if product.blank?
    price = product.price_currency.to_f
    if (user.currency || 0).to_f < price
      errors.add(:base, "Insufficient funds")
    end
  end

  # Refunds the user when an order transitions to `denied` unless a refund was already recorded.
  def refund_if_denied
    prev_status, new_status = saved_change_to_status
    return unless new_status == 'denied' && prev_status != 'denied'
    return unless cost.present? && cost.to_f > 0

    # If an explicit refund audit exists for this order, assume refund already happened.
    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
    refund_exists = if adapter.include?("sqlite")
      # sqlite: use json_extract
      Audit.where("action = ? AND json_extract(details, '$.order_id') = ?", 'order_refunded', id.to_s).exists?
    else
      # postgres and others: use jsonb operator and cast
      Audit.where("action = ? AND (details ->> 'order_id')::text = ?", 'order_refunded', id.to_s).exists?
    end

    # Fallback: some environments may serialize JSON slightly differently — do an in-memory check as a last resort.
    unless refund_exists
      refund_exists = Audit.where(action: 'order_refunded').to_a.any? { |a| a.details && a.details['order_id'].to_i == id }
    end

    return if refund_exists

    user.update!(currency: (user.currency || 0) + cost.to_f)

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

    Audit.create!(user: audit_user, project: nil, action: 'order_refunded', details: { order_id: id, amount: cost.to_f, previous_status: canonical_prev })
  end

  # Backwards-compatible predicate aliases for previous misspellings / synonyms
  def fulfilled?
    respond_to?(:status) ? (status.to_s == 'shipped' || status.to_s == 'fulfilled') : false
  end

  def fufilled?
    fulfilled?
  end
end
