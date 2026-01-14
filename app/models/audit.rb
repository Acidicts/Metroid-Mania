class Audit < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true

  validates :action, presence: true
end
