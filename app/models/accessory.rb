# == Schema Information
#
# Table name: accessories
#
#  id                 :bigint           not null, primary key
#  accessory_group_id :integer          not null
#  cost               :integer
#  created_at         :datetime         not null
#  name               :string
#  updated_at         :datetime         not null
#
# Indexes
#  index_accessories_on_accessory_group_id  (accessory_group_id)
#
class Accessory < ApplicationRecord
  belongs_to :accessory_group, inverse_of: :accessories
  has_one_attached :image
  has_many :regional_prices, dependent: :destroy, inverse_of: :priceable
  accepts_nested_attributes_for :regional_prices, allow_destroy: true, reject_if: proc { |attrs| attrs["region"].blank? }

  def image_url
    return nil unless image.respond_to?(:attached?) && image.attached?

    host = Rails.application.routes.default_url_options[:host]
    if host.present?
      Rails.application.routes.url_helpers.rails_blob_url(image, host: host)
    else
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    end
  end
end
