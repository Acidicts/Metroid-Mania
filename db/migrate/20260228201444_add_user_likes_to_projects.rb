class AddUserLikesToProjects < ActiveRecord::Migration[8.1]
  def change
    # the intention of this feature is to record "likes" by users on
    # projects.  rather than stuffing a single foreign key into the
    # projects table, create a proper join-like table with one record per
    # like.  this also solves the migration error: sqlite needs the target
    # table to exist before it can add a foreign key constraint.
    create_table :user_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.timestamps
    end

    # we no longer need a direct reference on projects; if you really do
    # want to cache a "last like" or similar you can add a separate
    # migration later.
    # add_reference :projects, :user_like, null: true, foreign_key: true
  end
end
