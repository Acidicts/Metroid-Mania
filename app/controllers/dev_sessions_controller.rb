class DevSessionsController < ApplicationController
  # Only available in development and test
  before_action :allow_dev_only

  def create
    email = params[:email]
    user = User.find_by(email: email)
    if user
      # application-level toggle; mimic behaviour of the real callback
      if SiteSetting.enabled?("disable_non_admin_logins", default: false) && !user.admin?
        render plain: "Logins disabled for non-admins", status: :forbidden
        return
      end

      # Set region on dev sign-in as well
      begin
        user.set_region_from_ip(request.remote_ip)
      rescue => e
        Rails.logger.warn("Failed to set region for dev user #{user.id}: #{e.message}")
      end

      session[:user_id] = user.id
      render plain: "Signed in", status: :ok
    else
      render plain: "No such user", status: :not_found
    end
  end

  private
  def allow_dev_only
    unless Rails.env.development? || Rails.env.test?
      head :not_found
    end
  end
end
