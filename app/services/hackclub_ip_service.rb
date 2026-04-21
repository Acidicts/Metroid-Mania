class HackclubIpService
  EU_COUNTRY_CODES = %w[
    AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE
  ].freeze

  def initialize(ip: nil)
    @ip = ip
  end

  def get_region_by_ip
    return nil unless @ip.present?

    begin
      response = HTTParty.get("https://ip.hackclub.com/ip/#{@ip}")
      if response.success?
        data = JSON.parse(response.body)
        normalize_region(data)
      else
        Rails.logger.warn "Failed to fetch region for IP #{@ip}: #{response.code} #{response.message}"
        nil
      end
    rescue => e
      Rails.logger.error "Error fetching region for IP #{@ip}: #{e.message}"
      nil
    end
  end

  private

  # Normalize IP geolocation output into the fixed set used by the app.
  def normalize_region(data)
    # ip.hackclub.com returns `country_iso_code`; keep `country_code` as fallback.
    country_code = data["country_iso_code"]&.to_s&.upcase
    country_code = data["country_code"]&.to_s&.upcase if country_code.blank?
    continent_code = data["continent_code"]&.to_s&.upcase

    return "United States" if country_code == "US"
    return "United Kingdom" if %w[GB UK].include?(country_code)
    return "India" if country_code == "IN"
    return "Canada" if country_code == "CA"
    return "Australia" if country_code == "AU"

    return "EU" if EU_COUNTRY_CODES.include?(country_code) || continent_code == "EU"

    "Rest of the World"
  end
end
