class AddTypeToChallenges < ActiveRecord::Migration[8.1]
  def change
    add_column :challenges, :type, :string, default: "multiplier", null: false

    # Since `type` is a reserved column for STI, but we are using it for
    # challenge categorization, disable inheritance on the model instead of
    # renaming the column. The model will opt out by setting
    # `self.inheritance_column = :_type_disabled`.
  end
end
