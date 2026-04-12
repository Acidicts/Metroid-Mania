class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :provider
      t.string :uid
      t.string :name
      t.string :slack_id
      t.string :verification_status
      t.integer :role
      t.float :currency

      t.timestamps
    end
  end
end
