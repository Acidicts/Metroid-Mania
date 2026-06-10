# == Schema Information
#
# Table name: accessory_groups
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  name       :string
#  product_id :integer          not null
#  required   :boolean          default: false, not null
#  updated_at :datetime         not null
#
# Indexes
#  index_accessory_groups_on_product_id  (product_id)
#
class AccessoryGroup < ApplicationRecord
  belongs_to :product, inverse_of: :accessory_groups
  has_many :accessories, dependent: :destroy, inverse_of: :accessory_group
  accepts_nested_attributes_for :accessories, allow_destroy: true, reject_if: :all_blank
end
