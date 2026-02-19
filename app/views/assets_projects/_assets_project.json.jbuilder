json.extract! assets_project, :id, :title, :description, :media_type, :shipped, :user_id, :created_at, :updated_at
json.url assets_project_url(assets_project, format: :json)
