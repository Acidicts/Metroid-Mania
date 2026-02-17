class AddShipToComments < ActiveRecord::Migration[8.1]
  def change
    add_reference :comments, :ship, foreign_key: true, index: true
  end
end
