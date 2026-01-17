# == Schema Information
#
# Table name: audits
#
#  id         :bigint           not null, primary key
#  action     :string           not null
#  created_at :datetime         not null
#  details    :json             default: {}
#  project_id :integer
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
class Audit < ApplicationRecord
  # Audits may be created by a user or by the system (nil user)
  belongs_to :user, optional: true
  belongs_to :project, optional: true

  validates :action, presence: true
end
