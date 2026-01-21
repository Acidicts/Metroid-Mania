class AddShipRequestToDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_reference :devlogs, :ship_request, foreign_key: true, index: true
  end
end
