class ConvertCommentsToPolymorphic < ActiveRecord::Migration[8.1]
  def up
    add_column :comments, :commentable_type, :string
    add_column :comments, :commentable_id, :bigint
    add_index :comments, [:commentable_type, :commentable_id], name: "index_comments_on_commentable"

    Comment.where.not(devlog_id: nil).update_all(
      "commentable_type = 'Devlog', commentable_id = devlog_id"
    )
    Comment.where.not(ship_id: nil).update_all(
      "commentable_type = 'Ship', commentable_id = ship_id"
    )

    remove_index :comments, name: "index_comments_on_devlog_id"
    remove_index :comments, name: "index_comments_on_ship_id"
    remove_column :comments, :devlog_id
    remove_column :comments, :ship_id
  end

  def down
    add_column :comments, :devlog_id, :integer
    add_column :comments, :ship_id, :integer
    add_index :comments, :devlog_id
    add_index :comments, :ship_id

    Comment.where(commentable_type: "Devlog").update_all("devlog_id = commentable_id")
    Comment.where(commentable_type: "Ship").update_all("ship_id = commentable_id")

    remove_index :comments, name: "index_comments_on_commentable"
    remove_column :comments, :commentable_type
    remove_column :comments, :commentable_id
  end
end
