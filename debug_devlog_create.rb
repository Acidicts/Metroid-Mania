p = Project.first
if p
  d = p.devlogs.build(title: 'Test auto', content: 'auto')
  d.log_date = Date.current
  d.duration_seconds = ([p.total_seconds.to_i - p.total_devlogged_seconds, 0].max)
  d.save!
  puts "Saved: log_date=#{d.log_date}, duration_seconds=#{d.duration_seconds}"
else
  puts 'No project found'
end