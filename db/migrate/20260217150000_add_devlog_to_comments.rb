class AddDevlogToComments < ActiveRecord::Migration[8.1]
  def change
    add_reference :comments, :devlog, null: true, foreign_key: true, index: true
  end
end
