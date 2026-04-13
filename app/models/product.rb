class Product < ApplicationRecord
  # don't accidentally blow away users' order history when an admin
  # deletes a product. the foreign key in the database enforces this
  # already, but having an AR-level restriction allows us to show a
  # sensible validation error instead of raising a constraint exception.
  has_many :orders, dependent: :restrict_with_error
  # each product may optionally be tied to an achievement. we store the
  # foreign key on `products.achievement_id`, so this is a `belongs_to`
  # association. earlier versions mistakenly used `has_one` which looked for
  # `achievements.product_id` and caused SQL errors when loading records.
  belongs_to :achievement, optional: true

  # Helpers/constants
  DEFAULT_MIN_GRANT_CENTS = 10_00
  DEFAULT_MAX_GRANT_CENTS = 100_00

  # Validation for variable grant ranges
  validates :credits_per_dollar, numericality: { greater_than: 0 }, allow_nil: true
  validates :grant_min_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :grant_max_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :grant_range_consistency

  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :limited, inclusion: { in: [ true, false ] }

  attribute :image_url, :string, default: "https://assets.bing-bong.uk/image_viewer.html?file=demo/penzance.jpg"
  attribute :description, :string, default: ""
  attribute :show, :boolean, default: true
  attribute :notch_cost, :integer, default: 1
  attribute :sale_discount, :integer, default: 0
  attribute :sale_date, :date, default: nil

  # legacy column name is `achievement_bool`; provide a friendlier alias so
  # code (and forms) can refer to `achievement_boolean`.  The database still
  # stores the value in `achievement_bool` and the migration that adds the
  # column is named accordingly.
  alias_attribute :achievement_boolean, :achievement_bool

  validate :notch_cost_is_int
  validate :achievement_configuration

  def not_grant?
    !variable_grant?
  end

  def notch_cost_is_int
    if notch_cost.present? && !notch_cost.is_a?(Integer)
      if notch_cost < 0
        self.notch_cost = abs(notch_cost)
      else
        self.notch_cost = 1
      end
    end
  end

  def set_image_from_url(url)
    self.image_url = url
    save
  end

  # Determine whether a given user may purchase this product.
  #
  # - If `achievement_boolean` is false the product is always unlocked.
  # - When the flag is true but there is no associated achievement the product
  #   should be considered locked (this used to return true, which meant
  #   checking "require achievement" with no achievement had no effect).
  # - Otherwise we delegate to `Achievement#unlocked_by?` which checks the
  #   user's earned achievements. `nil` users are treated as locked.
  def is_unlocked(user)
    return true unless achievement_boolean
    return false if achievement.blank?
    achievement.unlocked_by?(user)
  end

  # Returns the dollar value (float) for stored grant_amount_cents when used as an admin-configured default
  def grant_amount_dollars
    return nil unless grant_amount_cents
    (grant_amount_cents.to_f / 100.0)
  end

  def grant_amount_dollars=(val)
    return self.grant_amount_cents = nil if val.blank?
    self.grant_amount_cents = (val.to_f * 100).round
  end

  # Min and max dollars helpers for form/UI
  def grant_min_dollars
    (grant_min_cents || DEFAULT_MIN_GRANT_CENTS) / 100.0
  end

  def grant_min_dollars=(val)
    return self.grant_min_cents = nil if val.blank?
    self.grant_min_cents = (val.to_f * 100).round
  end

  def grant_max_dollars
    (grant_max_cents || DEFAULT_MAX_GRANT_CENTS) / 100.0
  end

  def grant_max_dollars=(val)
    return self.grant_max_cents = nil if val.blank?
    self.grant_max_cents = (val.to_f * 100).round
  end

  # Calculate credits for given dollar amount
  def credits_for_dollars(dollars)
    return nil if credits_per_dollar.blank?
    (dollars.to_f * credits_per_dollar.to_f)
  end

  # Calculate how many notches a grant should cost when expressed as dollars.
  # The business rule is: grant dollars / 10 = notches.
  def grant_notches_for_dollars(dollars)
    return nil if dollars.blank?
    (dollars.to_f / 10.0)
  end

  # Determine cost in credits for fixed product
  def cost_in_credits
    return cost_credits if cost_credits.present?
    return nil if price_currency.blank? || credits_per_dollar.blank?

    price_currency.to_f * credits_per_dollar.to_f
  end

  # Convenience predicate
  def variable_grant?
    !!variable_grant
  end

  def update_price_from_steam!
    return unless steam_app_id

    price_data = SteamService.get_price(steam_app_id)
    if price_data
      update(steam_price_cents: price_data["final"])
      # Logic to convert steam price (cents) to Mania currency?
      # Assuming 1 currency = $1.00 => 100 cents
      self.price_currency = price_data["final"] / 100.0
      save
    end
  end

  # Return the first active sale for this product.
  # If `quantity` is provided, restrict to sales matching that quantity.
  # A `nil` quantity will match any product-specific sale regardless of amount.
  def active_sale(quantity = nil)
    scope = Sale.active.where(product_id: id)
    scope = scope.where(quantity: quantity) if quantity
    scope.first
  end

  # Compute the effective notch cost after applying any active sale discount.
  # Returns an integer >= 0.
  def effective_notch_cost(quantity: nil)
    base = notch_cost.to_i
    if (s = active_sale(quantity))
      discounted = base - s.discount_notches.to_i
      return 0 if discounted < 0
      return discounted
    end
    base
  end

  ALLOWED_ORDER_STATUSES_FOR_DESTRUCTION = %w[pending submitted shipped].freeze

  def destroy!
    if orders.exists?
      orders.where.not(status: ALLOWED_ORDER_STATUSES_FOR_DESTRUCTION).destroy_all
      if orders.where.not(status: ALLOWED_ORDER_STATUSES_FOR_DESTRUCTION).exists?
        raise ActiveRecord::RecordNotDestroyed, "Cannot delete product while disallowed order statuses remain"
      end
      orders.destroy_all
    end

    super
  end

  private

  # Custom validation used when the admin sets the "require achievement"
  # checkbox in the product form.  The check box and the associated
  # `achievement_id` field are independent, so it's possible to check the
  # box and leave the dropdown blank.  That configuration should be
  # rejected instead of silently behaving as if there were no requirement.
  def achievement_configuration
    if achievement_boolean && achievement.blank?
      errors.add(:achievement, "must be selected when requiring an unlock")
    end
  end

  def grant_range_consistency
    if grant_min_cents && grant_max_cents && grant_min_cents > grant_max_cents
      errors.add(:grant_min_cents, "must be less than or equal to grant_max_cents")
    end
  end
end
