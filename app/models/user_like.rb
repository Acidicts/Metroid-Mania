# == Schema Information
#
# Table name: user_likes
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  project_id :integer          not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#  index_user_likes_on_project_id  (project_id)
#  index_user_likes_on_user_id     (user_id)
#
class UserLike < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :user_id, uniqueness: { scope: :project_id }
end
