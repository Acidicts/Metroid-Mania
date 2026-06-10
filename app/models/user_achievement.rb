# == Schema Information
#
# Table name: user_achievements
#
#  id              :bigint           not null, primary key
#  achievement_id  :integer          not null
#  created_at      :datetime         not null
#  unlocked_at     :datetime
#  updated_at      :datetime         not null
#  user_id         :integer          not null
#
# Indexes
#  index_user_achievements_on_achievement_id              (achievement_id)
#  index_user_achievements_on_user_id_and_achievement_id  (user_id, achievement_id) UNIQUE
#  index_user_achievements_on_user_id                     (user_id)
#
class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement

  validates :user_id, uniqueness: { scope: :achievement_id, message: "already has this achievement" }
end
