require "test_helper"
require "tempfile"

class CDNServiceTest < ActiveSupport::TestCase
  setup do
    # Ensure CdnService is loaded and then preserve/set CDN constants for tests.
    # Use CdnService (Zeitwerk inflection) and provide backward alias CDNService for compatibility.
    require Rails.root.join('app/services/cdn_service').to_s unless defined?(CdnService)
    CDNService = CdnService unless defined?(CDNService)

    @old_url = CdnService.const_get(:CDN_URL) rescue nil
    @old_key = CdnService.const_get(:CDN_KEY) rescue nil
    CdnService.const_set(:CDN_URL, "https://cdn.hackclub.com/api/v4")
    CdnService.const_set(:CDN_KEY, "sk_test_key")
  end

  teardown do
    CDNService.const_set(:CDN_URL, @old_url)
    CDNService.const_set(:CDN_KEY, @old_key)
  end

  # Helper to temporarily override Net::HTTP.start with a mock object
  def with_mock_http(mock_http)
    orig = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) do |*args, &blk|
      blk.call(mock_http)
    end

    yield
  ensure
    Net::HTTP.define_singleton_method(:start) { |*a, &b| orig.call(*a, &b) }
  end

  # Helper to create a fake Net::HTTP response that behaves like a Net::HTTPOK with a body
  class FakeSuccessResponse < Net::HTTPOK
    def initialize(body)
      super('1.1', '200', 'OK')
      @__body = body
    end

    def body
      @__body
    end
  end

  class FakeCreatedResponse < Net::HTTPCreated
    def initialize(body)
      super('1.1', '201', 'Created')
      @__body = body
    end

    def body
      @__body
    end
  end

  class FakeErrorResponse < Net::HTTPBadRequest
    def initialize(body = '')
      super('1.1', '400', 'Bad Request')
      @__body = body
    end

    def body
      @__body
    end
  end

  test "upload returns parsed JSON on success" do
    tmp = create_sample_image('upload_test.png')

    response_body = JSON.dump({ "url" => "https://cdn.hackclub.com/123/photo.png", "filename" => "photo.png" })
    fake_response = FakeCreatedResponse.new(response_body)

    mock_http = Object.new
    mock_http.define_singleton_method(:request) do |req|
      fake_response
    end

    with_mock_http(mock_http) do
      res = CDNService.upload(File.open(tmp, 'rb'))
      assert_equal "https://cdn.hackclub.com/123/photo.png", res['url']
      assert_equal "photo.png", res['filename']
    end
  end

  test "upload returns nil when CDN not configured" do
    CDNService.const_set(:CDN_URL, nil)
    assert_nil CDNService.upload(StringIO.new('data'))
  end

  test "upload_from_url posts url and returns parsed json" do
    url = 'https://example.com/image.jpg'
    response_body = JSON.dump({ "url" => "https://cdn.hackclub.com/abc/image.jpg" })
    fake_response = FakeSuccessResponse.new(response_body)

    captured_request = nil
    mock_http = Object.new
    mock_http.define_singleton_method(:request) do |req|
      captured_request = req
      fake_response
    end

    with_mock_http(mock_http) do
      res = CDNService.upload_from_url(url, download_auth: 'Bearer token')
      assert_equal "https://cdn.hackclub.com/abc/image.jpg", res['url']
      # ensure the request body contains the url
      assert_equal JSON.dump({ url: url }), captured_request.body
      # ensure header was set on request
      assert_equal 'application/json', captured_request['Content-Type']
      assert_equal 'Bearer sk_test_key', captured_request['Authorization']
      assert_equal 'Bearer token', captured_request['X-Download-Authorization']
    end
  end

  test "me returns parsed json on success" do
    response_body = JSON.dump({ "id" => "usr_abc", "storage_used" => 12345 })
    fake_response = FakeSuccessResponse.new(response_body)

    mock_http = Object.new
    mock_http.define_singleton_method(:request) do |req|
      fake_response
    end

    with_mock_http(mock_http) do
      res = CDNService.me
      assert_equal 'usr_abc', res['id']
      assert_equal 12345, res['storage_used']
    end
  end

  test "purge_cache returns true on success and false on non-success" do
    success_resp = FakeSuccessResponse.new('{}')
    fail_resp = FakeErrorResponse.new(JSON.dump({ error: 'Missing file parameter' }))

    mock_http_success = Object.new
    mock_http_success.define_singleton_method(:request) { |_req| success_resp }

    mock_http_fail = Object.new
    mock_http_fail.define_singleton_method(:request) { |_req| fail_resp }

    with_mock_http(mock_http_success) do
      assert_equal true, CDNService.purge_cache('https://example.com/foo')
    end

    with_mock_http(mock_http_fail) do
      assert_equal false, CDNService.purge_cache('https://example.com/foo')
    end

    # simulate exception
    orig = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |_a, &b| raise StandardError.new('boom') }
    begin
      assert_nil CDNService.purge_cache('https://example.com/foo')
    ensure
      Net::HTTP.define_singleton_method(:start) { |*a, &b| orig.call(*a, &b) }
    end
  end
end