user = User.first
service = HackatimeService.new(user.hackatime_api_key, slack_id: user.slack_id)
projects = service.get_all_projects
puts "Returned #{projects.size} projects"
projects.first(10).each_with_index do |p, i|
  puts "#{i+1}. #{p['name']} - recent: #{p['recent_seconds']} - total: #{p['seconds']}"
end
