# == Schema Information
#
# Table name: products
#
#  id                  :bigint           not null, primary key
#  achievement_bool    :boolean          default: false
#  achievement_id      :integer
#  base_cost           :integer          default 0
#  cost_credits        :float
#  created_at          :datetime         not null
#  credits_per_dollar  :float
#  description         :string
#  grant_amount_cents  :integer
#  grant_enabled       :boolean          default: false, not null
#  grant_max_cents     :integer
#  grant_min_cents     :integer
#  image_url           :string
#  limited             :boolean          default: false, not null
#  link                :string
#  name                :string
#  notch_cost          :integer
#  price_currency      :float
#  sale_discount       :integer
#  sale_time           :date
#  show                :boolean          default: true
#  steam_app_id        :integer
#  steam_price_cents   :integer
#  stock               :integer          default: 0
#  updated_at          :datetime         not null
#  variable_grant      :boolean          default: false, not null
#
# Indexes
#  index_products_on_achievement_id  (achievement_id)
#
class Product < ApplicationRecord
  # don't accidentally blow away users' order history when an admin
  # deletes a product. the foreign key in the database enforces this
  # already, but having an AR-level restriction allows us to show a
  # sensible validation error instead of raising a constraint exception.
  has_many :sales, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error

  has_many :accessory_groups, dependent: :destroy, inverse_of: :product
  has_many :accessories, through: :accessory_groups
  has_many :regional_prices, dependent: :destroy, inverse_of: :priceable
  accepts_nested_attributes_for :accessory_groups, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :regional_prices, allow_destroy: true, reject_if: proc { |attrs| attrs["region"].blank? }

  # ActiveStorage attachment for the product image. This is optional.
  has_one_attached :image

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

  attribute :physical, :boolean, default: false
  attribute :base_cost, :integer, default: 0

  def image_url
    if image.respond_to?(:attached?) && image.attached?
      product_image_url
    elsif defined?(@image_url_cache) && @image_url_cache.present?
      @image_url_cache
    elsif has_attribute?(:image_url) && self[:image_url].present?
      self[:image_url]
    else
      nil
    end
  end

  def image_url=(val)
    if has_attribute?(:image_url)
      write_attribute(:image_url, val)
    else
      @image_url_cache = val
    end
  end
  attribute :sale_discount, :integer, default: 0
  attribute :sale_date, :date, default: nil

  # legacy column name is `achievement_bool`; provide a friendlier alias so
  # code (and forms) can refer to `achievement_boolean`.  The database still
  # stores the value in `achievement_bool` and the migration that adds the
  # column is named accordingly.
  alias_attribute :achievement_boolean, :achievement_bool

  validate :achievement_configuration
  before_validation :ensure_regional_prices, on: :create
  before_validation :normalize_regional_price_regions

  REGIONS = [
    "United States",
    "United Kingdom",
    "India",
    "Canada",
    "Australia",
    "EU",
    "Rest of the World"
  ].freeze

  REGION_CANONICAL_MAP = {
    "US" => "United States",
    "UNITED STATES" => "United States",
    "UK" => "United Kingdom",
    "GB" => "United Kingdom",
    "UNITED KINGDOM" => "United Kingdom",
    "IN" => "India",
    "CA" => "Canada",
    "AU" => "Australia",
    "EU" => "EU",
    "REST OF THE WORLD" => "Rest of the World"
  }.freeze

  def self.canonical_region(region)
    return region if region.blank?
    normalized = region.to_s.strip
    REGION_CANONICAL_MAP.fetch(normalized.upcase, normalized)
  end

  def normalize_regional_price_regions
    regional_prices.each do |price|
      price.region = self.class.canonical_region(price.region)
    end

    accessory_groups.each do |group|
      group.accessories.each do |accessory|
        accessory.regional_prices.each do |price|
          price.region = self.class.canonical_region(price.region)
        end
      end
    end
  end

  def ensure_regional_prices
    return if regional_prices.any?

    REGIONS.each do |region|
      regional_prices.build(region: region)
    end
  end

  def not_grant?
    !variable_grant?
  end

  def standard_cost?
    return false unless not_grant?
    return false unless accessory_groups.empty?
    true
  end

  def cost(region)
    canonical = RegionalPrice.canonical_region(region)
    regional_price = regional_prices.find_by(region: canonical)
    if regional_price && regional_price.enabled?
      regional_price.cost
    else
      if self.regional_prices.where(region: "Rest of the World", enabled: true).exists?
        self.regional_prices.find_by(region: "Rest of the World").cost
      elsif self[:notch_cost].nil?
        1
      else
        self[:notch_cost].to_i
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

  # Calculate credits for given dollar amount.
  # credits_per_dollar is stored as dollars per credit, so its inverse (1/credits_per_dollar)
  # gives credits per dollar; e.g. 9 becomes 1/9.
  def credits_for_dollars(dollars)
    return nil unless credits_per_dollar.present?
    dollars.to_f / credits_per_dollar.to_f
  end

  # Calculate how many notches a grant should cost when expressed as dollars.
  # The business rule is: grant dollars / 10 = notches.
  def grant_notches_for_dollars(dollars)
    return nil if dollars.blank?
    (dollars.to_f / 10.0) / (self.credits_per_dollar || 1)
  end

  # Determine cost in credits for fixed product
  def cost_in_credits
    return cost_credits if cost_credits.present?
    return nil if price_currency.blank? || credits_per_dollar.blank?

    price_currency.to_f / credits_per_dollar.to_f
  end

  # Convenience predicate
  def variable_grant?
    self.variable_grant
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

  def physical?
    self.physical
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

  def product_image_url
    return nil unless image.respond_to?(:attached?) && image.attached?

    host = Rails.application.routes.default_url_options[:host]
    if host.present?
      Rails.application.routes.url_helpers.rails_blob_url(image, host: host)
    else
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    end
  end

  def grant_range_consistency
    if grant_min_cents && grant_max_cents && grant_min_cents > grant_max_cents
      errors.add(:grant_min_cents, "must be less than or equal to grant_max_cents")
    end
  end
end
