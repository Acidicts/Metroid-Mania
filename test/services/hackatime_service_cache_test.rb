require "test_helper"

class HackatimeServiceCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @original_cache = Rails.cache
    Rails.cache.clear
    @original_connection = HackatimeService.singleton_class.instance_method(:connection)
    @original_ttl = ENV['HACKATIME_CACHE_TTL_SECONDS']
    @original_bypass = ENV['HACKATIME_BYPASS_CACHE']
  end

  teardown do
    HackatimeService.singleton_class.define_method(:connection, @original_connection)
    ENV['HACKATIME_CACHE_TTL_SECONDS'] = @original_ttl
    ENV.delete('HACKATIME_BYPASS_CACHE') if @original_bypass.nil?
    ENV['HACKATIME_BYPASS_CACHE'] = @original_bypass if @original_bypass
    Rails.cache = @original_cache
    Rails.cache.clear
    travel_back
  end

  test "fetch_stats caches responses and bypass flag forces refetch" do
    ENV['HACKATIME_CACHE_TTL_SECONDS'] = '300'
    ENV.delete('HACKATIME_BYPASS_CACHE')
    assert_nil ENV['HACKATIME_BYPASS_CACHE'], "Expected bypass env to be nil at test start"
    assert_equal '300', ENV['HACKATIME_CACHE_TTL_SECONDS']

    # Use a fresh MemoryStore instance scoped to this test for deterministic behavior
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    fake = Class.new do
      attr_reader :calls
      def initialize
        @calls = 0
      end

      def get(path, params = nil)
        @calls += 1
        body = { data: { projects: [{ 'name' => 'X', 'total_seconds' => 100 }] }, trust_factor: { trust_value: 0 } }.to_json
        Struct.new(:success?, :body, :headers).new(true, body, {})
      end
    end.new

    HackatimeService.singleton_class.define_method(:connection) { fake }

    a = HackatimeService.fetch_stats('UID')
    assert_equal Hash, a.class
    assert_equal 1, fake.calls

    cache_key = "hackatime:stats:UID:#{HackatimeService::START_DATE}:none"
    assert Rails.cache.read(cache_key).present?, "Expected cache to contain key=#{cache_key} after first fetch"

    store = Rails.cache.instance_variable_get(:@data)
    assert store && store.any?, "Expected MemoryStore to have entries, got #{store.inspect}"
    assert store.keys.any? { |k| k.to_s.include?("hackatime:stats:UID") }, "Expected cache keys to include hackatime:stats:UID, got #{store.keys.inspect}"

    b = HackatimeService.fetch_stats('UID')
    assert_equal 1, fake.calls, "Second fetch should hit cache and not call API"

    ENV['HACKATIME_BYPASS_CACHE'] = '1'
    c = HackatimeService.fetch_stats('UID')
    assert_equal 2, fake.calls, "Bypass flag should force a refetch"
  end

  test "fetch_stats respects TTL expiry" do
    ENV['HACKATIME_CACHE_TTL_SECONDS'] = '1'
    ENV.delete('HACKATIME_BYPASS_CACHE')

    # Use a fresh MemoryStore instance scoped to this test for deterministic behavior
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    fake = Class.new do
      attr_reader :calls
      def initialize
        @calls = 0
      end

      def get(path, params = nil)
        @calls += 1
        body = { data: { projects: [{ 'name' => 'Y', 'total_seconds' => 200 }] }, trust_factor: { trust_value: 0 } }.to_json
        Struct.new(:success?, :body, :headers).new(true, body, {})
      end
    end.new

    HackatimeService.singleton_class.define_method(:connection) { fake }

    a = HackatimeService.fetch_stats('UID2')
    assert_equal 1, fake.calls

    travel 2.seconds

    b = HackatimeService.fetch_stats('UID2')
    assert_equal 2, fake.calls, "After TTL expiry, a new fetch should occur"
  end
end
