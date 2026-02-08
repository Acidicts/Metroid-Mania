
class CdnService
  require 'net/http'
  require 'uri'
  require 'json'

  CDN_URL = ENV['CDN_URL']
  CDN_KEY = ENV['CDN_KEY']

  # Purge a single URL from the CDN cache. Returns true on success, nil/false on failure.
  def self.purge_cache(url)
    return unless CDN_URL.present? && CDN_KEY.present?

    uri = URI.parse("#{CDN_URL}/purge")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{CDN_KEY}"
    request.content_type = "application/json"
    request.body = JSON.dump({ url: url })

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("CDN cache purge failed for #{url}: #{response.code} #{response.message}")
      return false
    end

    true
  rescue => e
    Rails.logger.error("CDN purge_cache exception: #{e.message}")
    nil
  end

  # Upload a file via multipart/form-data. Accepts an UploadedFile, File, or IO-like object.
  # Returns parsed JSON response on success (hash), or nil on failure.
  def self.upload(file)
    return unless CDN_URL.present? && CDN_KEY.present?

    uri = URI.parse("#{CDN_URL}/upload")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{CDN_KEY}"

    file_io = nil

    # Construct form data compatible with Net::HTTP#set_form
    form = if file.respond_to?(:path)
      filename = file.respond_to?(:original_filename) ? file.original_filename : File.basename(file.path)
      file_io = File.open(file.path, 'rb')
      # set_form accepts [name, IO, opts]
      [['file', file_io, { filename: filename, content_type: (file.content_type if file.respond_to?(:content_type)) }]]
    elsif file.respond_to?(:read)
      # Read into memory (useful for StringIO)
      data = file.read
      [['file', data, { filename: 'upload', content_type: 'application/octet-stream' }]]
    else
      Rails.logger.error("CDNService.upload called with invalid file: #{file.inspect}")
      return nil
    end

    request.set_form(form, 'multipart/form-data')

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPCreated)
      JSON.parse(response.body)
    else
      Rails.logger.error("CDN upload failed: #{response.code} #{response.message} #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("CDN upload exception: #{e.message}")
    nil
  ensure
    file_io.close if file_io && !file_io.closed?
  end

  # Upload an image from a remote URL. Optionally pass download_auth to set X-Download-Authorization header
  # Returns parsed JSON response on success, nil on failure.
  def self.upload_from_url(url, download_auth: nil)
    return unless CDN_URL.present? && CDN_KEY.present?

    uri = URI.parse("#{CDN_URL}/upload_from_url")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{CDN_KEY}"
    request["Content-Type"] = "application/json"
    request["X-Download-Authorization"] = download_auth if download_auth.present?
    request.body = JSON.dump({ url: url })

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPCreated)
      JSON.parse(response.body)
    else
      Rails.logger.error("CDN upload_from_url failed: #{response.code} #{response.message} #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("CDN upload_from_url exception: #{e.message}")
    nil
  end

  # Get authenticated account/quota information from CDN
  def self.me
    return unless CDN_URL.present? && CDN_KEY.present?

    uri = URI.parse("#{CDN_URL}/me")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{CDN_KEY}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error("CDN /me failed: #{response.code} #{response.message} #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("CDN /me exception: #{e.message}")
    nil
  end

  # Provide backward-compatible alias `CDNService` for existing code referencing it
  CDNService = CdnService unless defined?(CDNService)
end