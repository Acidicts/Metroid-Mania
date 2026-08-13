class AddAccessTokenToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :access_token, :string
  end
end
