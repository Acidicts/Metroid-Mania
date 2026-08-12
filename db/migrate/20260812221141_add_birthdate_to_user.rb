class AddBirthdateToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :birthdate, :string
  end
end
