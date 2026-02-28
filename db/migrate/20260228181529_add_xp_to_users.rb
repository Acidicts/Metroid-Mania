class AddXpToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :xp, :integer, default: 0, null: false
  end
end
