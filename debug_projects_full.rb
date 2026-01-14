user = User.first
if user && user.hackatime_api_key.present?
  uid = user.slack_id
  puts "Fetching stats for UID=#{uid}"
  stats = HackatimeService.fetch_stats(uid)
  puts "Top-level keys: #{stats.keys.inspect}"
  raw_projects = stats && stats[:projects] ? stats[:projects] : {}
  puts "Project count: #{raw_projects.size}"
  raw_projects.each do |name, seconds|
    puts "Project: #{name} => #{seconds.inspect}"
  end
  # Also fetch raw API JSON for full inspection
  response = HackatimeService.connection.get("users/#{uid}/stats", { features: 'projects' })
  puts "-- Raw response body:\n"
  puts response.body
else
  puts "Cannot test: user missing or missing API key"
end
