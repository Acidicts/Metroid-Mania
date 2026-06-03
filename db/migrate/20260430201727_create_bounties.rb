class CreateBounties < ActiveRecord::Migration[8.1]
  def change
    create_table :bounties do |t|
      t.string :name
      t.string :description
      t.references :type, null: false, foreign_key: true
      t.string :charm_slots
      t.integer :rewarded
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
