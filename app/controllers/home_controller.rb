class HomeController < ApplicationController
  def index
    @not_running_message = SiteSetting.get("not_running_message").to_s
  end
end
