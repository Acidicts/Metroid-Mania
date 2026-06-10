# == Schema Information
#
# Table name: posts
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  postable_id    :bigint           not null
#  postable_type  :string           not null
#  project_id     :integer          not null
#  updated_at     :datetime         not null
#  user_id        :integer
#
# Indexes
#  index_posts_on_postable_type_and_postable_id  (postable_type, postable_id) UNIQUE
#  index_posts_on_project_id                     (project_id)
#  index_posts_on_user_id                        (user_id)
#
class Post < ApplicationRecord
  belongs_to :project
  belongs_to :user
end
