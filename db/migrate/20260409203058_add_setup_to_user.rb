class AddSetupToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :setup, :boolean, default: false, null: false
  end
end
