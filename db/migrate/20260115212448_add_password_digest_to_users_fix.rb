class AddPasswordDigestToUsersFix < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:users)

    unless column_exists?(:users, :password_digest)
      add_column :users, :password_digest, :string
    end

    add_index :users, :uid unless index_exists?(:users, :uid)
  end
end
