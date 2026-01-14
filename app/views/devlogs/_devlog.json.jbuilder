json.extract! devlog, :id, :project_id, :title, :content, :log_date, :duration_minutes, :created_at, :updated_at
json.url devlog_url(devlog, format: :json)
