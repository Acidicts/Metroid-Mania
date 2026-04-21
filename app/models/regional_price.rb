class RegionalPrice < ApplicationRecord
  belongs_to :priceable, polymorphic: true

  attribute :enabled, :boolean, default: false
  attribute :cost, :integer, default: 1

  validates :region, presence: true, uniqueness: { scope: [ :priceable_type, :priceable_id ], case_sensitive: false }

  before_validation :normalize_region

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

  def normalize_region
    self.region = self.class.canonical_region(region)
  end

  def self.canonical_region(region)
    return region if region.blank?
    normalized = region.to_s.strip
    REGION_CANONICAL_MAP.fetch(normalized.upcase, normalized)
  end
end
