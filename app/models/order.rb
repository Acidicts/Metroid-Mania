require 'securerandom'

class Order < ApplicationRecord
  belongs_to :user
  belongs_to :product

  # Ensure cost is set and balance is deducted when creating an Order (status will be set to `pending`).
  # Set cost when creating; only deduct/validate balance when the order will be `pending`.
  before_create :set_cost_and_deduct_balance
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
    # Determine price in USD and cost (in credits).
    if product.variable_grant? && grant_amount_cents.present?
      dollars = grant_amount_cents.to_f / 100.0
      # Preserve explicitly provided price_usd/cost when present (tests and fixtures sometimes set cost manually)
      self.price_usd ||= dollars
      self.cost ||= product.credits_for_dollars(dollars)
    else
      # Fixed product: prefer explicit cost_credits; otherwise compute from price * ratio
      self.price_usd ||= product.price_currency.to_f
      self.cost ||= product.cost_in_credits
    end

    # Normalize nil costs to 0.0 so arithmetic and deductions are safe
    self.cost = (self.cost || 0).to_f

    self.status ||= 'pending'

    # Only deduct balance when creating a real pending order
    if status == 'pending'
      # Ensure user.currency is numeric and not nil
      user.update!(currency: (user.currency || 0).to_f - self.cost)
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

    if (user.currency || 0).to_f < required
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

    Audit.create!(user: audit_user, project: nil, action: 'order_refunded', details: { order_id: id, order_public_id: public_id, amount: cost.to_f, previous_status: canonical_prev })
  end

  public

  # to_param uses public_id for friendlier public URLs when present
  def to_param
    public_id.present? ? public_id : id.to_s
  end

  # Find an order by either numeric id or the public_id (e.g., '!a1B2c3')
  def self.find_by_param(param)
    return find(param) unless param.to_s.start_with?('!')
    find_by!(public_id: param.to_s)
  end

  # Backwards-compatible predicate aliases for previous misspellings / synonyms
  def fulfilled?
    respond_to?(:status) ? (status.to_s == 'shipped' || status.to_s == 'fulfilled') : false
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
