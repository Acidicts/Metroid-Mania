# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'openssl'

class SlackService
  # Accepts keyword args for flexibility and backwards compatibility.
  # Example: SlackService.new(token: ENV['SLACK_BOT_TOKEN'], client_id: ..., client_secret: ..., signing_secret: ...)
  def initialize(token: nil, client_id: nil, client_secret: nil, signing_secret: nil)
    @token = token || ENV['SLACK_BOT_TOKEN']
    @client_id = client_id || ENV['SLACK_CLIENT_ID']
    @client_secret = client_secret || ENV['SLACK_CLIENT_SECRET']
    @signing_secret = signing_secret || ENV['SLACK_SIGNING_SECRET']
  end

  # Accepts an array of Slack user IDs and returns an array of hashes:
  # [{id: 'U123', name: 'Name', pronouns: 'they/them', image: 'https://...'}, ...]
  def users_info(ids)
    return [] if ids.blank? || @token.blank?

    ids.map do |id|
      fetch_user_info(id)
    end.compact
  end

  # Verify Slack request signature using signing secret.
  # Headers should be a Hash with string keys (e.g., request.headers.to_h)
  # and body should be the raw request body string.
  def verify_signature(headers, body)
    return false if @signing_secret.blank?

    timestamp = headers['HTTP_X_SLACK_REQUEST_TIMESTAMP'] || headers['X-Slack-Request-Timestamp'] || headers['x-slack-request-timestamp']
    sig = headers['HTTP_X_SLACK_SIGNATURE'] || headers['X-Slack-Signature'] || headers['x-slack-signature']
    return false if timestamp.blank? || sig.blank?

    # Reject if timestamp is older than 5 minutes to prevent replay attacks
    if (Time.now.to_i - timestamp.to_i).abs > 60 * 5
      Rails.logger.info("SlackService.verify_signature: timestamp too old")
      return false
    end

    basestring = "v0:#{timestamp}:#{body}"
    computed = 'v0=' + OpenSSL::HMAC.hexdigest('sha256', @signing_secret, basestring)

    Rack::Utils.secure_compare(computed, sig)
  rescue => e
    Rails.logger.error("SlackService.verify_signature error: #{e.message}")
    false
  end

  private

  def fetch_user_info(id)
    Rails.cache.fetch("slack_user_#{id}", expires_in: 12.hours) do
      uri = URI("https://slack.com/api/users.info")
      uri.query = URI.encode_www_form(user: id)

      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{@token}"
      req['Accept'] = 'application/json'

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 5) do |http|
        http.request(req)
      end

      data = JSON.parse(res.body) rescue nil
      next unless data && data['ok'] && data['user'] && data['user']['profile']

      profile = data['user']['profile']

      # Slack provides both a real_name and a display_name; prefer display_name for UI labels
      display_name = profile['name'].presence
      real_name = profile['real_name'].presence
      name = display_name || real_name || data['user']['name']

      # Title / role on Slack profile
      title = profile['title'].presence || profile['job_title'].presence

      # Try to pull pronouns from the modern attribute or custom profile fields
      pronouns = profile['pronouns'] if profile['pronouns'].present?
      if pronouns.blank? && profile['fields'].is_a?(Hash)
        profile['fields'].each_value do |field|
          value = field.is_a?(Hash) ? field['value'] : nil
          label = field.is_a?(Hash) ? field['label'] : nil
          if value.present? && label.to_s.downcase.include?('pronoun')
            pronouns = value
            break
          end
        end
      end

      image = profile['image_192'] || profile['image_512'] || profile['image_72']

      { id: id, name: name, display_name: display_name, real_name: real_name, title: title, pronouns: pronouns, image: image }
    end
  rescue => e
    Rails.logger.error("SlackService.fetch_user_info(#{id}) failed: #{e.message}")
    nil
  end
end
