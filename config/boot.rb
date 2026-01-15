ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Load local environment variables from `.env` if Dotenv is available early in boot.
begin
  require "dotenv"
  Dotenv.load
rescue LoadError
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
