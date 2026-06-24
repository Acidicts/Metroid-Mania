# == Schema Information
#
# Table name: comments
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  devlog_id     :integer
#  last_editted  :datetime
#  message       :text
#  ship_id       :integer
#  system        :boolean          default(FALSE), not null
#  updated_at    :datetime         not null
#  user_id       :integer          not null
#
# Indexes
#  index_comments_on_devlog_id  (devlog_id)
#  index_comments_on_ship_id    (ship_id)
#  index_comments_on_user_id    (user_id)
#
class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true, optional: true

  attribute :system, :boolean, default: false

  validates :message, presence: true

  # Whether the given user is allowed to edit/delete this comment.
  # Admins and superadmins may always edit; otherwise only the comment owner may.
  def editable_by?(u)
    return false if u.nil?
    return true if u.admin? || u.superadmin?

    # Only admins may edit comments attached to a Ship
    return false if commentable.is_a?(Ship)

    user == u
  end

  def system?
    self.system
  end
end
