user = User.first
if user
  puts "User: #{user.email}, slack_id: #{user.slack_id}, api_key present: #{user.hackatime_api_key.present?}"
  if user.hackatime_api_key.present?
    service = HackatimeService.new(user.hackatime_api_key, slack_id: user.slack_id)
    puts "Invoking get_all_projects..."
    projects = service.get_all_projects
    puts "Projects: #{projects.inspect}"
    
    if projects.any?
      puts "Running get_project_stats for '#{projects.first}'..."
      stats = service.get_project_stats(projects.first)
      puts "Stats for #{projects.first}: #{stats}"
    end
  else
    puts "User has no API key."
  end
else
  puts "No user found."
end
