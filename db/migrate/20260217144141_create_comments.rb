class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      t.text :message
      t.datetime :last_editted

      t.timestamps
    end
  end
end
