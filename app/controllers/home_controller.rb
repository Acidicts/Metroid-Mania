class HomeController < ApplicationController
  def index
    redirect_to dashboard_path
  end
end
