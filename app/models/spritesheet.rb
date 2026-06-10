# == Schema Information
#
# Table name: spritesheets
#
#  id             :bigint           not null, primary key
#  assets_item_id :integer          not null
#  created_at     :datetime         not null
#  name           :string
#  updated_at     :datetime         not null
#  url            :string
#
# Indexes
#  index_spritesheets_on_assets_item_id  (assets_item_id)
#
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
