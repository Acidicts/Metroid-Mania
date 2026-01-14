class Product < ApplicationRecord
  has_many :orders
  
  def update_price_from_steam!
    return unless steam_app_id
    
    price_data = SteamService.get_price(steam_app_id)
    if price_data
      update(steam_price_cents: price_data['final'])
      # Logic to convert steam price (cents) to Mania currency?
      # Assuming 1 currency = $1.00 => 100 cents
      self.price_currency = price_data['final'] / 100.0 
      save
    end
  end
end
