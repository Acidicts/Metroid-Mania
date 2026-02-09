class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    # Successful callback from OmniAuth
    auth = request.env['omniauth.auth']
    Rails.logger.info "OmniAuth Info: #{auth.info.inspect}"
    Rails.logger.info "OmniAuth Credentials: #{auth.credentials.inspect}"
    Rails.logger.info "OmniAuth Extra: #{auth.extra.inspect}"

    user = User.from_omniauth(auth)

    # Update user's region based on request IP on every sign-in (don't break login if the lookup fails)
    begin
      user.set_region_from_ip(request.remote_ip)
    rescue => e
      Rails.logger.warn("Failed to set region for user #{user.id}: #{e.message}")
    end

    session[:user_id] = user.id

    origin = request.env['omniauth.origin'] || params[:origin] || root_path

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
