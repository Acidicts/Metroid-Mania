class RegionalPrice < ApplicationRecord
  belongs_to :priceable, polymorphic: true

  attribute :enabled, :boolean, default: false
  attribute :cost, :integer, default: 1
end
