class LeaderboardsController < ApplicationController
  def index
    # Get all users with their total credits from ships
    # Use left outer join to include users with no ships
    # Sum credits_awarded from all ships for each user (NULL values are treated as 0)
    # Order users by their available balance (shipped credits on active projects minus amount_spent)
    # IMPORTANT: aggregate ships via the user's projects (users -> projects -> ships), not ships the user created.
    @users = User.where.not(name: "Deleted User").not_system.left_joins(projects: :ships)
                 .select(
                   "users.*, \
                    COALESCE(SUM(CASE WHEN projects.id IS NOT NULL AND projects.deleted_at IS NULL THEN ships.credits_awarded ELSE 0 END), 0) AS total_shipped, \
                    (COALESCE(SUM(CASE WHEN projects.id IS NOT NULL AND projects.deleted_at IS NULL THEN ships.credits_awarded ELSE 0 END), 0) - COALESCE(users.amount_spent, 0)) AS total_balance"
                 )
                 .group('users.id')
                 .order(Arel.sql('total_balance DESC'))
  end
end
