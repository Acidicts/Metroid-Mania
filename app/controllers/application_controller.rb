class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :logged_in?, :admin?

  before_action :warn_if_app_url_mismatch, if: -> { Rails.env.development? }

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def admin?
    # Treat either a DB-set admin role or the env-defined superadmin as admin
    logged_in? && (current_user.admin? || current_user.superadmin?)
  end

  def require_login
    unless logged_in?
      redirect_to root_path, alert: "You must be logged in to access this section"
    end
  end

  def require_admin
    unless admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end

  private

  def warn_if_app_url_mismatch
    app_url = ENV.fetch('APP_URL', 'http://localhost:3000')
    begin
      app_uri = URI(app_url)
      if app_uri.host != request.host || app_uri.port != request.port
        Rails.logger.warn("APP_URL (#{app_url}) differs from request host (#{request.base_url}). Set APP_URL to #{request.base_url} to avoid OmniAuth CSRF/session issues.")
        flash.now[:alert] = "Development: APP_URL differs from this host. Set APP_URL to #{request.base_url} to fix OAuth CSRF errors."
      end
    rescue => e
      Rails.logger.warn("Invalid APP_URL: #{e.message}")
    end
  end
end
