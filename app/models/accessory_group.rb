class AccessoryGroup < ApplicationRecord
  belongs_to :product, inverse_of: :accessory_groups
  has_many :accessories, dependent: :destroy, inverse_of: :accessory_group
  accepts_nested_attributes_for :accessories, allow_destroy: true, reject_if: :all_blank
end
