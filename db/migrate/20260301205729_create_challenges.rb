class CreateChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :challenges do |t|
      t.string :title
      t.text :description
      t.integer :reward_notches
      t.datetime :start_at
      t.datetime :end_at
      t.boolean :active
      t.float :multiplier

      t.timestamps
    end
  end
end
