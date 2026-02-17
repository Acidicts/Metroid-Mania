// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Completely disable Turbo Drive to prevent frozen UI issues
// This disables automatic page navigation via Turbo but keeps Frames and Streams
import { Turbo } from "@hotwired/turbo-rails"
Turbo.session.drive = false

console.log('Turbo Drive disabled - using traditional page loads to prevent frozen UI')
