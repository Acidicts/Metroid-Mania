require "test_helper"

class HackclubIpServiceTest < ActiveSupport::TestCase
  def with_mock_httparty(response)
    orig = HTTParty.method(:get)
    HTTParty.define_singleton_method(:get) { |_url| response }
    yield
  ensure
    HTTParty.define_singleton_method(:get) { |*a, &b| orig.call(*a, &b) }
  end

  class FakeResponse
    attr_reader :body, :code, :message

    def initialize(success:, body:, code: 200, message: "OK")
      @success = success
      @body = body
      @code = code
      @message = message
    end

    def success?
      @success
    end
  end

  test "maps major country codes to requested region buckets" do
    mapping = {
      "US" => "United States",
      "GB" => "United Kingdom",
      "IN" => "India",
      "CA" => "Canada",
      "AU" => "Australia",
      "DE" => "EU",
      "JP" => "Rest of the World"
    }

    mapping.each do |country_code, expected|
      resp = FakeResponse.new(success: true, body: { country_code: country_code, continent_code: "AS" }.to_json)
      with_mock_httparty(resp) do
        assert_equal expected, HackclubIpService.new(ip: "1.2.3.4").get_region_by_ip
      end
    end
  end

  test "maps country_iso_code from Hack Club IP payload" do
    resp = FakeResponse.new(success: true, body: { country_iso_code: "GB", continent_code: "EU", is_in_european_union: false }.to_json)
    with_mock_httparty(resp) do
      assert_equal "United Kingdom", HackclubIpService.new(ip: "82.35.250.223").get_region_by_ip
    end
  end

  test "falls back to country_code when country_iso_code is missing" do
    resp = FakeResponse.new(success: true, body: { country_code: "CA", continent_code: "NA" }.to_json)
    with_mock_httparty(resp) do
      assert_equal "Canada", HackclubIpService.new(ip: "1.2.3.4").get_region_by_ip
    end
  end

  test "returns EU when continent is EU even without country code" do
    resp = FakeResponse.new(success: true, body: { continent_code: "EU" }.to_json)
    with_mock_httparty(resp) do
      assert_equal "EU", HackclubIpService.new(ip: "1.2.3.4").get_region_by_ip
    end
  end

  test "returns nil when lookup request fails" do
    resp = FakeResponse.new(success: false, body: "{}", code: 500, message: "Internal Server Error")
    with_mock_httparty(resp) do
      assert_nil HackclubIpService.new(ip: "1.2.3.4").get_region_by_ip
    end
  end

  test "returns nil when ip is blank" do
    assert_nil HackclubIpService.new(ip: nil).get_region_by_ip
    assert_nil HackclubIpService.new(ip: "").get_region_by_ip
  end
end
