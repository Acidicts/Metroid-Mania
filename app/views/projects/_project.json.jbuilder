json.extract! project, :id, :user_id, :name, :repository_url, :status, :total_seconds, :created_at, :updated_at
json.hackatime_ids project.hackatime_ids || []
json.hackatime_id project.hackatime_ids&.first || project.hackatime_id
json.url project_url(project, format: :json)
