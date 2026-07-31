require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "dependent :orders prevents destroy (non-bang) when orders exist" do
    product = products(:one)
    user = users(:one)
    product.update_column(:notch_cost, 1)
    user.adjust_charm_notches!(10)
    user.orders.where(product: product).destroy_all
    Order.create!(user: user, product: product, status: "denied", notch_cost: 1)
    Sale.where(product: product).delete_all
    # restrict_with_error prevents destroy (non-bang) from succeeding
    assert_not product.destroy
    assert product.errors[:base].any?
  end

  test "can destroy product with no orders" do
    product = Product.create!(name: "ToDelete", notch_cost: 1, stock: 10, limited: false)
    assert_nothing_raised { product.destroy! }
  end

  test "product can have an achievement" do
    ach = Achievement.create!(title: "Test", requirement_type: "min_notches", requirement_value: 1)
    product = Product.create!(name: "AchProd", achievement: ach, stock: 10, limited: false)
    assert_equal ach, product.achievement
  end

  test "cost returns regional price when enabled" do
    product = products(:one)
    rp = product.regional_prices.find_or_create_by!(region: "United States") { |r| r.cost = 3; r.enabled = true }
    assert_equal 3, product.cost("United States")
  end

  test "cost falls back to Rest of the World when region disabled" do
    product = products(:one)
    product.regional_prices.update_all(enabled: false)
    product.regional_prices.find_or_create_by!(region: "Rest of the World") { |r| r.cost = 7; r.enabled = true }
    assert_equal 7, product.cost("Nonexistent Region")
  end

  test "cost falls back to notch_cost when no regional prices enabled" do
    product = Product.create!(name: "Basic", notch_cost: 5, stock: 10, limited: false)
    product.regional_prices.update_all(enabled: false)
    assert_equal 5, product.cost("United States")
  end

  test "is_unlocked returns true when achievement_bool is false" do
    product = Product.create!(name: "NoAch", achievement_bool: false, stock: 10, limited: false)
    assert product.is_unlocked(nil)
  end

  test "image_url returns default value when no image" do
    product = Product.new
    assert product.image_url.present?
  end

  test "active_sale returns nil when no sale" do
    product = Product.create!(name: "NoSale", stock: 10, limited: false)
    assert_nil product.active_sale
  end

  test "active_sale returns matching sale" do
    product = products(:one)
    sale = Sale.create!(name: "Active", starts_at: 1.day.ago, ends_at: 1.day.from_now, product: product, quantity: 1, discount_notches: 2)
    assert_equal sale, product.active_sale
  end

  test "active_sale returns nil for expired sale" do
    product = products(:one)
    Sale.create!(name: "Expired", starts_at: 2.days.ago, ends_at: 1.day.ago, product: product, quantity: 1, discount_notches: 2)
    assert_nil product.active_sale
  end

  test "grant_amount_dollars returns dollars from cents" do
    product = Product.create!(name: "Grant", grant_amount_cents: 1500, stock: 10, limited: false)
    assert_equal 15.0, product.grant_amount_dollars
  end

  test "grant_amount_dollars returns nil when no cents" do
    product = Product.new
    assert_nil product.grant_amount_dollars
  end

  test "grant_amount_dollars= sets cents from dollars" do
    product = Product.create!(name: "Grant", stock: 10, limited: false)
    product.grant_amount_dollars = 25.50
    assert_equal 2550, product.grant_amount_cents
  end

  test "grant_amount_dollars= clears cents when blank" do
    product = Product.create!(name: "Grant", grant_amount_cents: 100, stock: 10, limited: false)
    product.grant_amount_dollars = nil
    assert_nil product.grant_amount_cents
  end

  test "grant_min_dollars returns default when nil" do
    product = Product.new
    assert_equal Product::DEFAULT_MIN_GRANT_CENTS / 100.0, product.grant_min_dollars
  end

  test "grant_max_dollars returns default when nil" do
    product = Product.new
    assert_equal Product::DEFAULT_MAX_GRANT_CENTS / 100.0, product.grant_max_dollars
  end

  test "grant_min_dollars= sets cents" do
    product = Product.create!(name: "GM", stock: 10, limited: false)
    product.grant_min_dollars = 50.0
    assert_equal 5000, product.grant_min_cents
  end

  test "grant_max_dollars= sets cents" do
    product = Product.create!(name: "GM", stock: 10, limited: false)
    product.grant_max_dollars = 200.0
    assert_equal 20000, product.grant_max_cents
  end

  test "credits_for_dollars calculates credits" do
    product = Product.create!(name: "Cred", credits_per_dollar: 2.0, stock: 10, limited: false)
    assert_equal 20.0, product.credits_for_dollars(10.0)
  end

  test "credits_for_dollars returns nil when no credits_per_dollar" do
    product = Product.new
    assert_nil product.credits_for_dollars(10.0)
  end

  test "grant_notches_for_dollars divides by 10" do
    product = Product.new
    assert_equal 5.0, product.grant_notches_for_dollars(50.0)
  end

  test "grant_notches_for_dollars returns nil for nil input" do
    product = Product.new
    assert_nil product.grant_notches_for_dollars(nil)
  end

  test "cost_in_credits uses cost_credits when present" do
    product = Product.create!(name: "CC", cost_credits: 10.0, stock: 10, limited: false)
    assert_equal 10.0, product.cost_in_credits
  end

  test "cost_in_credits calculates from price and credits_per_dollar" do
    product = Product.create!(name: "CC2", price_currency: 5.0, credits_per_dollar: 2.0, stock: 10, limited: false)
    assert_equal 10.0, product.cost_in_credits
  end

  test "cost_in_credits returns nil when missing data" do
    product = Product.create!(name: "CC3", stock: 10, limited: false)
    assert_nil product.cost_in_credits
  end

  test "variable_grant? returns true when set" do
    product = Product.create!(name: "VG", variable_grant: true, stock: 10, limited: false)
    assert_predicate product, :variable_grant?
  end

  test "variable_grant? returns false when not set" do
    product = Product.create!(name: "VG2", stock: 10, limited: false)
    assert_not product.variable_grant?
  end

  test "not_grant? returns true when not variable_grant" do
    product = Product.create!(name: "NG", stock: 10, limited: false)
    assert_predicate product, :not_grant?
  end

  test "physical? returns true when physical attribute is true" do
    product = Product.create!(name: "Phys", physical: true, stock: 10, limited: false)
    assert_predicate product, :physical?
  end

  test "grant_range_consistency rejects min > max" do
    product = Product.new(name: "Range", grant_min_cents: 500, grant_max_cents: 100, stock: 10, limited: false)
    assert_not product.valid?
    assert product.errors[:grant_min_cents].any?
  end

  test "ensure_regional_prices creates default regions on create" do
    product = Product.create!(name: "RegPrice", stock: 10, limited: false)
    assert product.regional_prices.count >= Product::REGIONS.count
  end

  test "normalize_regional_price_regions normalizes aliases" do
    product = Product.create!(name: "Norm", stock: 10, limited: false)
    # "US" is an alias for "United States" in the canonical map
    rp = product.regional_prices.find_or_initialize_by(region: "United States")
    rp.cost = 5
    rp.enabled = true
    rp.save!
    # Verify canonical_region works for alias
    assert_equal "United States", Product.canonical_region("US")
    assert_equal "United States", Product.canonical_region("us")
  end

  test "set_image_from_url updates image_url" do
    product = Product.create!(name: "Img", stock: 10, limited: false)
    product.set_image_from_url("https://example.com/img.png")
    assert_equal "https://example.com/img.png", product.image_url
  end

  test "image_url= stores in cache when no column" do
    product = Product.new
    product.image_url = "https://example.com/test.png"
    assert_equal "https://example.com/test.png", product.image_url
  end

  test "REGION_CANONICAL_MAP maps known abbreviations" do
    assert_equal "United States", Product::REGION_CANONICAL_MAP["US"]
    assert_equal "United Kingdom", Product::REGION_CANONICAL_MAP["UK"]
    assert_equal "India", Product::REGION_CANONICAL_MAP["IN"]
  end
end
