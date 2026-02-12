class HackatimeService
  BASE_URL = "https://hackatime.hackclub.com"
  #             YYYY-MM-DD
  START_DATE = ENV["HACKATIME_START_DATE"] || "2025-12-15"

  def initialize(slack_id: nil)
    @slack_id = slack_id
  end

  def get_trusted_status(slack_id: nil)
    uid = slack_id || @slack_id
    Rails.logger.info "HackatimeService: Resolving trust factor. slack_id: #{uid}"
    return nil unless uid

    response = self.class.connection.get("users/#{uid}/trust_factor") do |req|
      req.headers["Authorization"] = "Bearer #{ENV["HACKATIME_API_KEY"]}" if ENV["HACKATIME_API_KEY"].present?
    end

    if response.success?
      data = JSON.parse(response.body)
      Rails.logger.info "HackatimeService trust_factor response (truncated): #{response.body[0..200]}"

      # Return a structured result matching the API docs so callers can inspect either field
      {
        trust_level: data["trust_level"],
        trust_value: data["trust_value"]
      }
    elsif response.status == 404
      # 404 is expected for users not yet tracked in Hackatime
      Rails.logger.debug "HackatimeService: User not found (404) for slack_id=#{uid}"
      nil
    else
      Rails.logger.error "HackatimeService trust_factor error: #{response.status} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "HackatimeService trust_factor exception: #{e.message}"
    nil
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
  # This version uses an instance-level cache to avoid calling the API repeatedly
  # during a single request/operation.
  def get_project_stats(project_name, start_date: START_DATE)
    return 0 unless @slack_id

    stats = fetch_stats_cached(start_date: start_date)
    return 0 unless stats && stats[:projects]

    stats[:projects][project_name] || 0
  end

  # Fetch stats but memoize per-instance per-date window to prevent duplicate
  # HTTP calls when multiple project lookups are performed during a request.
  def fetch_stats_cached(start_date: START_DATE, end_date: nil)
    @stats_cache ||= {}
    key = "#{start_date}-#{end_date}"
    @stats_cache[key] ||= (self.class.fetch_stats(@slack_id, start_date: start_date, end_date: end_date) || { projects: {} })
  end

  # Return a hash mapping project name => seconds (convenience)
  def get_projects(start_date: START_DATE, end_date: nil)
    fetch_stats_cached(start_date: start_date, end_date: end_date)[:projects] || {}
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

    cache_key = "hackatime:stats:#{hackatime_uid}:#{start_date}:#{end_date || 'none'}"
    ttl_seconds = (ENV['HACKATIME_CACHE_TTL_SECONDS'] || 300).to_i
    bypass_cache = ENV['HACKATIME_BYPASS_CACHE'].present?

    unless bypass_cache
      cached = Rails.cache.read(cache_key)
      if cached
        Rails.logger.debug "HackatimeService: cache hit for #{cache_key}"
        return cached
      end
    end

    Rails.logger.info "HackatimeService: GET users/#{hackatime_uid}/stats with params: #{params}"
    response = connection.get("users/#{hackatime_uid}/stats", params)

    if response.success?
      data = JSON.parse(response.body)
      Rails.logger.info "HackatimeService: Stats response headers: #{response.headers}"
      Rails.logger.info "HackatimeService: Stats response body (truncated): #{response.body[0..200]}"
      
      projects = data.dig("data", "projects") || []
      result = {
        projects: projects.to_h { |p| [ p["name"], p["total_seconds"].to_i ] },
        banned: data.dig("trust_factor", "trust_value") == 1
      }

      Rails.cache.write(cache_key, result, expires_in: ttl_seconds.seconds) unless bypass_cache
      result
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
