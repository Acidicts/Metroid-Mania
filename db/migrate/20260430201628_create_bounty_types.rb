class CreateBountyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :bounty_types do |t|
      t.string :type

      t.timestamps
    end
  end
end
