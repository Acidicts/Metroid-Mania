class LeaderboardsController < ApplicationController
  def index
    # Use the global Stats API key for leaderboards
    api_key = ENV['HACKATIME_API_KEY']
    
    if api_key.present?
      service = HackatimeService.new(api_key)
      @leaderboard = service.get_leaderboard
    else
      @leaderboard = []
      flash.now[:alert] = "Leaderboard API Key not configured."
    end
  end
end
