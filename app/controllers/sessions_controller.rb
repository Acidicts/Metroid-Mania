class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    # Successful callback from OmniAuth
    auth = request.env['omniauth.auth']
    Rails.logger.info "OmniAuth Info: #{auth.info.inspect}"
    Rails.logger.info "OmniAuth Credentials: #{auth.credentials.inspect}"
    Rails.logger.info "OmniAuth Extra: #{auth.extra.inspect}"

    user = User.from_omniauth(auth)
    session[:user_id] = user.id

    origin = request.env['omniauth.origin'] || params[:origin] || root_path
    
    flash[:success] = "Signed in successfully!"
    redirect_to origin, notice: "Signed in successfully! Info: #{auth.info.inspect}"
  end

  def failure
    Rails.logger.warn("OmniAuth failure: #{params[:message]}")
    redirect_to root_path, alert: "Authentication failed: #{params[:message] || 'Unknown error'}"
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Signed out!"
  end
end
