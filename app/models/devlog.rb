class Devlog < ApplicationRecord
  belongs_to :project

  # Duration must be an integer and present. The controller enforces a 15-minute minimum
  # for owner-initiated ship requests; the model allows shorter entries (useful for tests/edge-cases).
  validates :duration_minutes, presence: true,
                               numericality: { only_integer: true, greater_than_or_equal_to: 1, message: "must be a positive integer" }
end
