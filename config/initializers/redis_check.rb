# config/initializers/redis_check.rb

begin
  # Double-check that this line says .new and NOT .current
  redis_client = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))

  if redis_client.ping == "PONG"
    puts "✓ Redis is connected and working perfectly."
  else
    puts "⚠ Redis responded, but not with the expected PONG."
  end
rescue Redis::BaseConnectionError => e
  puts "✖ Redis connection failed during initialization: #{e.message}"
rescue StandardError => e
  puts "✖ An unexpected error occurred while checking Redis: #{e.message}"
end
