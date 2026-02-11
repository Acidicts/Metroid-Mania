namespace :hackatime do
  desc "Enqueue Hackatime status sync jobs for users with a Slack ID. Use LIMIT env var to limit number processed."
  task sync_all: :environment do
    limit = ENV['LIMIT']&.to_i
    users = User.where.not(slack_id: [nil, '']).order(:id)
    users = users.limit(limit) if limit && limit > 0

    users.find_each do |u|
      HackatimeSyncJob.perform_later(u.id)
      HackatimeProjectSyncJob.perform_later(u.id)
    end

    puts "Enqueued HackatimeSyncJob and HackatimeProjectSyncJob for #{users.count} users"
  end
end
