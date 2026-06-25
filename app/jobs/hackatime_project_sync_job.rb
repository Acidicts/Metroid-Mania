class HackatimeProjectSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user && (user.slack_id.present? || user.email.present?)

    user.sync_hackatime_projects!
  rescue => e
    Rails.logger.error "HackatimeProjectSyncJob failed for user_id=#{user_id}: #{e.message}"
    raise e
  end
end
