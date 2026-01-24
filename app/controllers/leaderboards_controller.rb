class LeaderboardsController < ApplicationController
  def index
    # Get all users with their total credits from ships
    # Use left outer join to include users with no ships
    # Sum credits_awarded from all ships for each user (NULL values are treated as 0)
    @users = User.left_joins(:ships)
                 .select('users.*, COALESCE(SUM(ships.credits_awarded), 0) as total_credits')
                 .group('users.id')
                 .order('total_credits DESC')
  end
end
