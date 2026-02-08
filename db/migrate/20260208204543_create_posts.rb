class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :postable_type, null: false
      t.bigint :postable_id, null: false

      t.timestamps
    end

    add_index :posts, [ :postable_type, :postable_id ], unique: true
  end
end
