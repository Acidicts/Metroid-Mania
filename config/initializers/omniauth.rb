require 'omniauth/strategies/hackclub'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :hackclub, ENV.fetch('HACKCLUB_CLIENT_ID'), ENV.fetch('HACKCLUB_CLIENT_SECRET'),
    scope: 'profile email name slack_id verification_status',
    callback_url: "#{ENV.fetch('APP_URL', 'http://localhost:3000')}/auth/hackclub/callback"
end

OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true
OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.request_validation_phase = nil
