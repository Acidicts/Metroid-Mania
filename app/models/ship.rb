class Ship < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :devlogged_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :credits_awarded, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
