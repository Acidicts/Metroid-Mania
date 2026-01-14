class AddHackatimeApiKeyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hackatime_api_key, :string
  end
end
