class AddNameAndSlackIdToRsvps < ActiveRecord::Migration[8.1]
  def up
    add_column :rsvps, :name, :string, null: false, default: ""
    add_column :rsvps, :slack_id, :string, null: false, default: ""

    execute <<~SQL.squish
      UPDATE rsvps
      SET
        name = COALESCE(users.name, ''),
        slack_id = COALESCE(users.slack_id, '')
      FROM users
      WHERE users.id = rsvps.user_id
    SQL

    change_column_null :rsvps, :user_id, true

    add_index :rsvps, :slack_id

    change_column_default :rsvps, :name, from: "", to: nil
    change_column_default :rsvps, :slack_id, from: "", to: nil
  end

  def down
    change_column_default :rsvps, :name, from: nil, to: ""
    change_column_default :rsvps, :slack_id, from: nil, to: ""

    remove_index :rsvps, column: :slack_id

    change_column_null :rsvps, :user_id, false

    remove_column :rsvps, :name
    remove_column :rsvps, :slack_id
  end
end
