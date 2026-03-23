class HomeController < ApplicationController
  def index
    if current_user
      redirect_to dashboard_path
    else
      @featured_projects = Project.order(total_seconds: :desc).limit(6)
    end
  end
end
