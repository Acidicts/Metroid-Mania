class HackclubIpService

  def initialize(ip: nil)
    @ip = ip
  end

  def get_region_by_ip
    return nil unless @ip.present?

    begin
      response = HTTParty.get("https://ip.hackclub.com/ip/#{@ip}")
      if response.success?
        data = JSON.parse(response.body)
        return data['continent_code']
      else
        Rails.logger.warn "Failed to fetch region for IP #{@ip}: #{response.code} #{response.message}"
        return nil
      end
    rescue => e
      Rails.logger.error "Error fetching region for IP #{@ip}: #{e.message}"
      return nil
    end
  end
end
