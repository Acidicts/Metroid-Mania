class Accessory < ApplicationRecord
  belongs_to :accessory_group, inverse_of: :accessories
end
