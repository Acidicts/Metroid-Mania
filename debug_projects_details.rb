user = User.first
if user && user.hackatime_api_key.present?
  uid = user.slack_id
  puts "Fetching parsed stats for UID=#{uid}"
  response = HackatimeService.connection.get("users/#{uid}/stats", { features: 'projects' })
  data = JSON.parse(response.body)
  projects = data.dig('data','projects') || []
  puts "Projects raw count: #{projects.size}"
  projects.each_with_index do |p, idx|
    puts "--- project[#{idx}] keys: #{p.keys.inspect}"
    puts p.inspect
  end
else
  puts "Cannot test: user missing or missing API key"
end
