class HackatimeSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user && user.slack_id.present?

    user.sync_hackatime_status!
  rescue => e
    Rails.logger.error "HackatimeSyncJob failed for user_id=#{user_id}: #{e.message}"
    raise e
  end
end
