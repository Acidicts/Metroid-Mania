class HackclubAuthService
  BASE_URL = "https://auth.hackclub.com"
  CACHE_TTL_SECONDS = 300

  def initialize(user)
    @user = user
    @access_token = user.access_token
  end

  # me function from github.com/hackclub/stardance in app/services/hca_service.rb edited to remove need for access_token param
  def me
    raise ArgumentError, "access_token is required" if @access_token.blank?

    response = connection.get("/api/v1/me") do |req|
      req.headers["Authorization"] = "Bearer #{@access_token}"
      req.headers["Accept"] = "application/json"
    end

    unless response.success?
      Rails.logger.warn("HCA /me fetch failed with status #{response.status}")
      return nil
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.warn("HCA /me fetch error: #{e.class}: #{e.message}")
    nil
  end

  def get_user
    result = me
    result&.dig("identity") || {}
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
