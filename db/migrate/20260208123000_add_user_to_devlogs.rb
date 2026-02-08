class AddUserToDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_reference :devlogs, :user, foreign_key: true, index: true
  end
end
