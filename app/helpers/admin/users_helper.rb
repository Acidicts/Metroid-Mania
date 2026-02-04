module Admin::UsersHelper
  # Returns a human-readable Hackatime trusted status for the given Slack ID.
  # Memoizes results in-memory for the duration of the request to avoid repeated API calls.
  def get_trusted_status(slack_id: nil)
    return nil unless slack_id.present?

    # Always fetch live data from Hackatime instead of using request-level caching
    Rails.logger.info "Admin::UsersHelper#get_trusted_status: fetching live trust for #{slack_id}"
    service_result = HackatimeService.new(slack_id: slack_id).get_trusted_status

    # Support structured Hash result or scalar and return the live trust_level when possible
    if service_result.is_a?(Hash)
      level = service_result[:trust_level] || service_result["trust_level"]
      value = service_result[:trust_value] || service_result["trust_value"]

      # Prefer string trust_level (e.g. "blue", "verified"); fall back to numeric trust_value
      return level.presence || value
    else
      return service_result
    end
  rescue => e
    Rails.logger.error "Admin::UsersHelper#get_trusted_status error: #{e.message}"
    nil
  end
end
