# == Schema Information
#
# Table name: rsvps
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  name       :string           not null
#  slack_id   :string           not null
#  updated_at :datetime         not null
#  user_id    :integer
#
# Indexes
#  index_rsvps_on_slack_id  (slack_id)
#  index_rsvps_on_user_id   (user_id)
#
class Rsvp < ApplicationRecord
  belongs_to :user, optional: true

  before_validation :normalize_fields

  validates :name, presence: true
  validates :slack_id, presence: true

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.slack_id = slack_id.to_s.strip
  end
end
