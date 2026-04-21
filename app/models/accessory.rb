class Accessory < ApplicationRecord
  belongs_to :accessory_group, inverse_of: :accessories
  has_many :regional_prices, dependent: :destroy, inverse_of: :priceable
  accepts_nested_attributes_for :regional_prices, allow_destroy: true, reject_if: proc { |attrs| attrs["region"].blank? }
end
