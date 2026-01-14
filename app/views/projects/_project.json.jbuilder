json.extract! project, :id, :user_id, :name, :repository_url, :status, :hackatime_id, :total_seconds, :created_at, :updated_at
json.url project_url(project, format: :json)
