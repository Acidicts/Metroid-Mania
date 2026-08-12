require Rails.root.join("lib/omniauth/strategies/hackclub")

if ENV["HACKCLUB_CLIENT_ID"].present? && ENV["HACKCLUB_CLIENT_SECRET"].present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    if ENV["HQ"]&.downcase == "true"
      provider_options = {
        scope: "profile email name slack_id verification_status basic_info address"
      }
    else
      provider_options = {
        scope: "profile email name slack_id verification_status"
      }
    end

    # Optional explicit redirect URI for environments that require a fixed host.
    # When unset, the custom strategy callback_url uses request.base_url.
    if ENV["HACKCLUB_REDIRECT_URI"].present?
      provider_options[:callback_url] = ENV["HACKCLUB_REDIRECT_URI"]
    end

    provider :hackclub,
             ENV["HACKCLUB_CLIENT_ID"],
             ENV["HACKCLUB_CLIENT_SECRET"],
             **provider_options
  end
else
  Rails.logger.warn("Hack Club OAuth is not configured. Set HACKCLUB_CLIENT_ID and HACKCLUB_CLIENT_SECRET for login to work.")
end

OmniAuth.config.allowed_request_methods = [ :post, :get ]
OmniAuth.config.silence_get_warning = true
OmniAuth.config.logger = Rails.logger
OmniAuth.config.request_validation_phase = nil
