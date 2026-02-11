json.extract! devlog, :id, :project_id, :title, :content, :log_date, :duration_seconds, :created_at, :updated_at
# Provide legacy field for clients expecting minutes
json.duration_minutes (devlog.duration_seconds_total.to_i / 60)
json.url devlog_url(devlog, format: :json)
