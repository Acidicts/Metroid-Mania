class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :logged_in?, :admin?

  before_action :warn_if_app_url_mismatch, if: -> { Rails.env.development? }

  # Graceful handling for unique constraint races (e.g., duplicate pending orders)
  rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique
  rescue_from ActiveRecord::StatementInvalid, with: :handle_record_not_unique

  def current_user
    return @current_user if defined?(@current_user)

    user_id = session[:user_id] || cookies.signed[:user_id]
    @current_user = User.find_by(id: user_id)

    unless @current_user
      session.delete(:user_id)
      cookies.delete(:user_id)
    end

    @current_user
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

  def handle_record_not_unique(exception)
    msg = exception.message.to_s
    # If this appears to be the 'duplicate pending order' unique index, try to find the existing pending order and redirect
    if msg.include?("orders.user_id, orders.product_id") || msg.match?(/orders.*user_id.*product_id/)
      prod_id = params[:product_id] || params.dig(:order, :product_id)
      if prod_id.present? && current_user
        existing = current_user.orders.find_by(product_id: prod_id, status: 'pending')
        if existing
          redirect_to existing, notice: "Order already placed"
          return
        end
      end
    end

    # Not handled above — re-raise for visibility
    raise exception
  end
end
