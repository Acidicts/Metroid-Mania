require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Hackclub < OmniAuth::Strategies::OAuth2
      option :name, 'hackclub'

      option :client_options, {
        site: 'https://auth.hackclub.com',
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token'
      }

      uid { raw_info['identity']['id'] }

      info do
        identity = raw_info['identity']
        {
          name: "#{identity['first_name']} #{identity['last_name']}".strip,
          email: identity['primary_email'],
          slack_id: identity['slack_id'],
          verification_status: identity['verification_status'],
          admin: identity['admin']
        }
      end

      extra do
        {
          'raw_info' => raw_info
        }
      end

      def raw_info
        @raw_info ||= access_token.get('/api/v1/me').parsed
      end
    end
  end
end
