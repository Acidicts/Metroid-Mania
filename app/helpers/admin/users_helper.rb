module Admin::UsersHelper
  # Returns a human-readable Hackatime trusted status for the given Slack ID.
  # Memoizes results in-memory for the duration of the request to avoid repeated API calls.
  def get_trusted_status(slack_id: nil)
    return nil unless slack_id.present?

    @trusted_status_cache ||= {}
    return @trusted_status_cache[slack_id] if @trusted_status_cache.key?(slack_id)

    Rails.logger.info "Admin::UsersHelper#get_trusted_status: fetching live trust for #{slack_id}"
    service_result = HackatimeService.new(slack_id: slack_id).get_trusted_status

    if service_result.is_a?(Hash)
      level = service_result[:trust_level] || service_result["trust_level"]
      value = service_result[:trust_value] || service_result["trust_value"]
      result = level.presence || value
    else
      result = service_result
    end

    @trusted_status_cache[slack_id] = result
  rescue => e
    Rails.logger.error "Admin::UsersHelper#get_trusted_status error: #{e.message}"
    @trusted_status_cache[slack_id] = nil
  end

  def trusted_status_icon(status)
    case status.to_s
    when "blue" then "🔵"
    when "green" then "🟢"
    when "yellow" then "🟡"
    when "red" then "🔴"
    else "-"
    end
  end

  def verification_status_icon(verification_status)
    case verification_status.to_s.downcase
    when "verified" then "✅"
    when "needs submission" then "⌛"
    else "❌"
    end
  end
end
