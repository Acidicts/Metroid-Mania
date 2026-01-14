user = User.first
uid = user.slack_id
response = HackatimeService.connection.get("users/#{uid}/stats", { features: 'projects' })
data = JSON.parse(response.body)
projects = data.dig('data','projects') || []
puts "direct GET projects count: #{projects.size}"
