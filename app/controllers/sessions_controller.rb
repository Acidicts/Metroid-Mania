class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def ensure_guest_exists
    User.find_or_create_by!(provider: "guest", uid: "guest") do |user|
      user.name = "Guest"
      user.email = "guest@bing-bong.uk"
      user.role ||= :user
    end
  end

  def guest
    user = ensure_guest_exists
    session[:user_id] = user.id
    flash_pass("Signed in as guest!")
    redirect_to root_path
  end

  def create
    # Successful callback from OmniAuth
    auth = request.env["omniauth.auth"]
    Rails.logger.info "OmniAuth Info: #{auth.info.inspect}"
    Rails.logger.info "OmniAuth Credentials: #{auth.credentials.inspect}"
    Rails.logger.info "OmniAuth Extra: #{auth.extra.inspect}"

    user = User.from_omniauth(auth)

    # block logins if the setting is flipped and the user isn't an admin
    if SiteSetting.enabled?("disable_non_admin_logins", default: false) && !user.admin?
      flash_warn("Logins are temporarily disabled for non-admin users")
      redirect_to root_path and return
    end

    # Update user's region based on request IP on every sign-in (don't break login if the lookup fails)
    begin
      user.set_region_from_ip(request.remote_ip)
    rescue => e
      Rails.logger.warn("Failed to set region for user #{user.id}: #{e.message}")
    end

    session[:user_id] = user.id

    origin = request.env["omniauth.origin"] || params[:origin] || root_path

    flash_pass("Signed in successfully!")
    redirect_to origin
  end

  def failure
    Rails.logger.warn("OmniAuth failure: #{params[:message]}")
    flash_warn("Authentication failed: #{params[:message] || 'Unknown error'}")
    redirect_to root_path
  end

  def destroy
    session[:user_id] = nil
    flash_pass("Signed out!")
    redirect_to root_path
  end
end
