json.extract! product, :id, :name, :steam_app_id, :price_currency, :steam_price_cents, :created_at, :updated_at
json.url product_url(product, format: :json)
