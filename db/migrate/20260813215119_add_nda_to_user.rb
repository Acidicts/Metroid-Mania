class AddNdaToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nda, :boolean, default: false
  end
end
