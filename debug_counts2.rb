user = User.first
uid = user.slack_id
all_default = HackatimeService.fetch_stats(uid) # default START_DATE
all_full = HackatimeService.fetch_stats(uid, start_date: nil) # request all-time
recent = HackatimeService.fetch_stats(uid, start_date: 30.days.ago.to_date.to_s)
puts "default-start_date count: #{all_default[:projects].size}"
puts "explicit nil (all-time) count: #{all_full[:projects].size}"
puts "recent (30d) count: #{recent[:projects].size}"
