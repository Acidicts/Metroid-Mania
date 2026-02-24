class AllowNullProjectIdOnProjectTags < ActiveRecord::Migration[8.1]
  def change
    # project_id used to be required but global tags should be allowed.
    # future migrations may remove the foreign key entirely but we keep it
    # for referential integrity; only the null constraint is relaxed.
    change_column_null :project_tags, :project_id, true
  end
end
