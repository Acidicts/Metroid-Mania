# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class SlackOauthService
  def initialize(client_id: nil, client_secret: nil)
    @client_id = client_id || ENV['SLACK_CLIENT_ID']
    @client_secret = client_secret || ENV['SLACK_CLIENT_SECRET']
  end

  # Exchange a temporary authorization code for an access token.
  # Returns the parsed JSON response from Slack or nil on error.
  def exchange_code(code, redirect_uri: nil)
    return nil if @client_id.blank? || @client_secret.blank? || code.blank?

    uri = URI('https://slack.com/api/oauth.v2.access')

    params = { client_id: @client_id, client_secret: @client_secret, code: code }
    params[:redirect_uri] = redirect_uri if redirect_uri.present?

    req = Net::HTTP::Post.new(uri)
    req.set_form_data(params)

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 5) do |http|
      http.request(req)
    end

    data = JSON.parse(res.body) rescue nil
    unless data && data['ok']
      Rails.logger.error("SlackOauthService.exchange_code failed: #{data.inspect}")
      return nil
    end

    data
  rescue => e
    Rails.logger.error("SlackOauthService.exchange_code error: #{e.message}")
    nil
  end
end
