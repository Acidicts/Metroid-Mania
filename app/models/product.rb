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

  attribute :achievement_boolean, :boolean, default: false

  validate :notch_cost_is_int

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

  def is_unlocked(user)
    return true unless achievement_boolean
    if achievement
      achievement.unlocked_by?(user)
    else
      true
    end
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

  def destroy!
    if Order.where(product_id: id).exists?
      Order.where(product_id: id).destroy_all
    end
    super
  end

  private

  def grant_range_consistency
    if grant_min_cents && grant_max_cents && grant_min_cents > grant_max_cents
      errors.add(:grant_min_cents, "must be less than or equal to grant_max_cents")
    end
  end
end
