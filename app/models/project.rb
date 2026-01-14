class Project < ApplicationRecord
  belongs_to :user
  has_many :devlogs, dependent: :destroy
  has_many :audits, dependent: :nullify
  
  validates :name, presence: true
  validates :repository_url, presence: true

  def total_devlogged_seconds
    devlogs.sum(:duration_minutes) * 60
  end

  def update_time_from_hackatime!
    return unless user.hackatime_api_key.present?
    
    # Use hackatime_id (which stores the project name from dropdown) if present, else fallback to local name
    target_name = hackatime_id.presence || name

    service = HackatimeService.new(user.hackatime_api_key, slack_id: user.slack_id)
    seconds = service.get_project_stats(target_name)
    update(total_seconds: seconds) if seconds > 0
  end

  def time
    remaining = [total_seconds.to_i - total_devlogged_seconds, 0].max
    hours = (remaining / 3600).floor
    minutes = ((remaining % 3600) / 60).floor
    "#{hours} hrs #{minutes} mins"
  end

  # Allowed statuses for projects
  STATUSES = %w[pending approved rejected denied].freeze

  # Can this project be shipped? Must be approved and have a devlog created after approval
  def can_be_shipped?
    return false unless status == 'approved' && approved_at.present?
    devlogs.where('created_at >= ?', approved_at).exists?
  end

  # Award credits to the project owner based on credits_per_hour and total_seconds
  # Returns the amount awarded (float) or nil if no rate provided
  def award_credits!(rate)
    return nil if rate.blank?

    hours = total_seconds.to_f / 3600.0
    amount = rate.to_f * hours

    user.update!(currency: (user.currency || 0) + amount)

    amount
  end
end
