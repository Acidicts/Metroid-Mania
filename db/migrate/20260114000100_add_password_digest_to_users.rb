class AddPasswordDigestToUsers < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:users)

    unless column_exists?(:users, :password_digest)
      add_column :users, :password_digest, :string
    end

    add_index :users, :uid unless index_exists?(:users, :uid)

    if column_exists?(:users, :password)
      begin
        require "bcrypt"
      rescue LoadError
        say "bcrypt not available; skipping password migration"
        return
      end

      migration_user = Class.new(ActiveRecord::Base) do
        self.table_name = "users"
      end

      migration_user.reset_column_information
      say_with_time "Migrating plain `password` to `password_digest`" do
        migration_user.find_each do |u|
          next if u.respond_to?(:password_digest) && u.password_digest.present?

          pw = u.read_attribute(:password) if u.respond_to?(:read_attribute)
          next unless pw.present?

          u.update_column(:password_digest, BCrypt::Password.create(pw))
        end
      end
    end
  end

  def down
    return unless table_exists?(:users)

    remove_index :users, :uid if index_exists?(:users, :uid)
    remove_column :users, :password_digest if column_exists?(:users, :password_digest)
  end
end
