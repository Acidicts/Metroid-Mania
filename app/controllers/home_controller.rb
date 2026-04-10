class HomeController < ApplicationController
  def index
    # The home page is a public landing page for signed-in users.
    # Keep this action render the view instead of redirecting to the dashboard.
  end
end
