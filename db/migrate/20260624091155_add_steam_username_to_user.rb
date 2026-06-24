class AddSteamUsernameToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :steam_username, :string
  end
end
