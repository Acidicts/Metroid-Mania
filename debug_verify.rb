user = User.first
if user && user.hackatime_api_key.present?
  service = HackatimeService.new(user.hackatime_api_key, slack_id: user.slack_id)
  puts "Invoking get_all_projects..."
  projects = service.get_all_projects
  puts "Projects Result: #{projects.inspect}"
  
  if projects.any?
    first = projects.first
    puts "Checking structure: Name=#{first['name']}, Seconds=#{first['seconds']}"
  end
else
  puts "Cannot test: User missing."
end
