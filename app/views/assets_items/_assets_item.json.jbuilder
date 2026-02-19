json.extract! assets_item, :id, :title, :description, :media_type, :shipped, :project_id, :created_at, :updated_at
json.url assets_item_url(assets_item, format: :json)
