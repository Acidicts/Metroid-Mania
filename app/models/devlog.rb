class Devlog < ApplicationRecord
  belongs_to :project

  # Require a minimum of 15 minutes per devlog
  validates :duration_minutes, presence: true,
                               numericality: { only_integer: true, greater_than_or_equal_to: 15, message: "must be at least 15 minutes" }
end
