class SteamService
  include HTTParty
  base_uri 'http://store.steampowered.com/api'

  def self.get_app_details(app_id)
    response = get("/appdetails", query: { appids: app_id })
    return nil unless response.success?

    data = response[app_id.to_s]
    return nil unless data && data['success']

    data['data']
  end

  def self.get_price(app_id)
    details = get_app_details(app_id)
    return nil unless details && details['price_overview']

    details['price_overview']
  end
end
