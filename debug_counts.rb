user = User.first
uid = user.slack_id
all = HackatimeService.fetch_stats(uid)
recent = HackatimeService.fetch_stats(uid, start_date: 30.days.ago.to_date.to_s)
puts "all projects count: #{all[:projects].size}"
puts "recent projects count: #{recent[:projects].size}"
puts "sample all keys: #{all[:projects].keys.first(10).inspect}"
