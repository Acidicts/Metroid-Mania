class LeaderboardsController < ApplicationController
  def index
    # Cache the leaderboard for 5 minutes to reduce database load
    @users = Rails.cache.fetch("leaderboard_rankings", expires_in: 5.minutes) do
      # Get all users with their total credits from ships
      # Use left outer join to include users with no ships
      # Sum credits_awarded from all ships for each user (NULL values are treated as 0)
      # Order users by their available balance (shipped credits on active projects minus amount_spent)
      # IMPORTANT: aggregate ships via the user's projects (users -> projects -> ships), not ships the user created.
      # build an array at cache time; sorting by free_notches happens below in Ruby
      users = User.where.not(name: "Deleted User").not_system.left_joins(projects: :ships)
          .select(
            "users.*, \
             COALESCE(SUM(CASE WHEN projects.id IS NOT NULL AND projects.deleted_at IS NULL THEN ships.credits_awarded ELSE 0 END), 0) AS total_shipped, \
             (COALESCE(SUM(CASE WHEN projects.id IS NOT NULL AND projects.deleted_at IS NULL THEN ships.credits_awarded ELSE 0 END), 0) + COALESCE(users.credit_offset, 0) - COALESCE(users.amount_spent, 0)) AS total_balance"
          )
          .group("users.id")
          .order(Arel.sql("total_balance DESC"))
          .to_a

      # while we cached by balance to reduce DB load, the leaderboard page ranks by free_notches,
      # so sort the resulting array now to avoid needing `order` in the view (and since cached
      # value is an Array we can't call AR methods on it after retrieval).
      users.sort_by! { |u| -u.free_notches }
      users
    end
  end
end
