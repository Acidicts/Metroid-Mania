class Spritesheet < ApplicationRecord
  belongs_to :assets_item

  validates :url, presence: true
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :name, presence: true

  # Predicate for URL presence (CDN-based)
  def url?
    url.present?
  end
end
