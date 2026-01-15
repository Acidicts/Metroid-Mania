class HackatimeService
  BASE_URL = "https://hackatime.hackclub.com"
  #             YYYY-MM-DD
  START_DATE = "2025-12-15"

  def initialize(slack_id: nil)
    @slack_id = slack_id
  end

  # Instance method interface for Controllers
  def get_all_projects
    Rails.logger.info "HackatimeService: Resolving UID. slack_id: #{@slack_id}"
    return [] unless @slack_id

    # Get totals starting from START_DATE
    all_stats = self.class.fetch_stats(@slack_id, start_date: START_DATE)
    # Get recent totals (last 30 days) for ordering by recency
    recent_start = 30.days.ago.to_date.to_s
    recent_stats = self.class.fetch_stats(@slack_id, start_date: recent_start)

    all_projects = all_stats && all_stats[:projects] ? all_stats[:projects] : {}
    recent_projects = recent_stats && recent_stats[:projects] ? recent_stats[:projects] : {}

    Rails.logger.info "HackatimeService: Found #{all_projects.size} projects since #{START_DATE} and #{recent_projects.size} recent projects for UID=#{@slack_id}"

    projects = all_projects.map do |name, total_seconds|
      {
        'name' => name,
        'seconds' => total_seconds,
        'recent_seconds' => recent_projects[name] || 0
      }
    end

    # Sort by recent_seconds desc, then seconds desc, then name
    projects.sort_by { |p| [-p['recent_seconds'].to_i, -p['seconds'].to_i, p['name'].downcase] }
  end

  def get_leaderboard
    response = self.class.connection.get("leaderboard") do |req|
      req.headers["Authorization"] = "Bearer #{ENV["HACKATIME_API_KEY"]}" if ENV["HACKATIME_API_KEY"].present?
    end
    
    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.error "HackatimeService leaderboard error: #{response.status}"
      []
    end
  rescue => e
    Rails.logger.error "HackatimeService leaderboard exception: #{e.message}"
    []
  end
  
  # Method to fetch stats for the current user (used for sync)
  def get_project_stats(project_name)
    return 0 unless @slack_id

    stats = self.class.fetch_stats(@slack_id)
    return 0 unless stats && stats[:projects]

    stats[:projects][project_name] || 0
  end

  # --- Adaptation of provided Service Logic ---

  def self.fetch_authenticated_user(access_token)
    response = connection.get("authenticated/me") do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
    end

    if response.success?
      data = JSON.parse(response.body)
      data["id"]&.to_s
    else
      Rails.logger.error "HackatimeService authenticated/me error: #{response.status}"
      nil
    end
  rescue => e
    Rails.logger.error "HackatimeService authenticated/me exception: #{e.message}"
    nil
  end

  def self.fetch_stats(hackatime_uid, start_date: START_DATE, end_date: nil)
    params = { features: "projects", test_param: true }
    params[:start_date] = start_date if start_date.present?
    params[:end_date] = end_date if end_date

    Rails.logger.info "HackatimeService: GET users/#{hackatime_uid}/stats with params: #{params}"
    response = connection.get("users/#{hackatime_uid}/stats", params)

    if response.success?
      data = JSON.parse(response.body)
      Rails.logger.info "HackatimeService: Stats response headers: #{response.headers}"
      Rails.logger.info "HackatimeService: Stats response body (truncated): #{response.body[0..200]}"
      
      projects = data.dig("data", "projects") || []
      
      {
        projects: projects.to_h { |p| [ p["name"], p["total_seconds"].to_i ] },
        banned: data.dig("trust_factor", "trust_value") == 1
      }
    else
      Rails.logger.error "HackatimeService error: #{response.status} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "HackatimeService exception: #{e.message}"
    nil
  end

  class << self
    def connection
      @connection ||= Faraday.new(url: "#{BASE_URL}/api/v1") do |conn|
        conn.headers["Content-Type"] = "application/json"
        conn.headers["User-Agent"] = "MetroidMania/1.0"
        conn.headers["RACK_ATTACK_BYPASS"] = ENV["HACKATIME_BYPASS_KEYS"] if ENV["HACKATIME_BYPASS_KEYS"].present?
      end
    end
  end
end
