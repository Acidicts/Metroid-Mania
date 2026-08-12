class HackclubAuthService
  BASE_URL = "https://auth.hackclub.com"
  CACHE_TTL_SECONDS = 300

  def initialize(user)
    @user = user
  end

  def get_user
    cache_key = "hca:identity:#{@user.hca_id}"
    bypass_cache = ENV["HCA_BYPASS_CACHE"].present?

    unless bypass_cache
      cached = Rails.cache.read(cache_key)
      return cached unless cached.nil?
    end

    response = self.class.connection.get("api/v1/identities/#{@user.hca_id}") do |req|
      req.headers["Authorization"] = "Bearer #{ENV["HACKCLUB_PROGRAM_KEY"]}"
    end

    result =
      if response.success?
        JSON.parse(response.body)["identity"]
      elsif response.status == 404
        Rails.logger.debug "HackclubAuthService: User not found (404) for hca_id=#{@user.hca_id}"
        nil
      elsif response.status == 403
        Rails.logger.debug "HackclubAuthService: Insufficient Permissions / Scopes"
        nil
      elsif response.status == 401
        Rails.logger.debug "HackclubAuthService: Unauthorised missing or invalid token"
        nil
      else
        Rails.logger.error "HackclubAuthService identity error: #{response.status} - #{response.body}"
        nil
      end

    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL_SECONDS) unless bypass_cache
    result
  end

  def get_user_addresses
    user_data = get_user
    user_data["addresses"] || []
  end

  def get_address_from_id(id)
    return nil if id.nil?
    addresses = get_user_addresses
    addresses.find { |item| item["id"].to_s == id.to_s || item[:id].to_s == id.to_s }
  end

  class << self
    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |conn|
        conn.headers["Content-Type"] = "application/json"
        conn.headers["User-Agent"] = "MetroidMania/1.0"
      end
    end
  end
end
