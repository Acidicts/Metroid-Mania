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
