class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :logged_in?, :admin?, :feature_enabled?, :slack_profile
  helper MarkdownHelper

  before_action :warn_if_app_url_mismatch, if: -> { Rails.env.development? }
  before_action :load_charm_slots

  # DB-backed feature flag helper (falls back to ENV_<NAME>_ENABLED)
  def feature_enabled?(name)
    if defined?(SiteSetting)
      SiteSetting.enabled?(name, default: ENV.fetch("#{name.to_s.upcase}_ENABLED", "true") == "true")
    else
      val = ENV.fetch("#{name.to_s.upcase}_ENABLED", "true")
      %w[1 true yes on].include?(val.to_s.downcase)
    end
  end

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

  def slack_profile
    return @slack_profile if defined?(@slack_profile)

    user = current_user
    if user&.slack_id.present?
      @slack_profile = Rails.cache.fetch("slack_profile_#{user.slack_id}", expires_in: 1.hour) do
        begin
          profile = SlackService.new.users_info([ user.slack_id ]).first
          profile.present? ? profile : nil
        rescue => e
          Rails.logger.error("ApplicationController#slack_profile Slack fetch error for #{user.id}: #{e.message}")
          nil
        end
      end
    end
    @slack_profile
  end

  def logged_in?
    !!current_user
  end

  def admin?
    return false unless logged_in?
    current_user.admin? || current_user.superadmin?
  end

  def require_login
    unless logged_in?
      flash_warn("You must be logged in to access this section")
      redirect_to root_path and return
    end
  end

  def require_admin
    if !admin?
      flash_warn("Not authorized")
      redirect_to root_path and return
    end
  end

  def require_superadmin
    if !current_user.superadmin?
      flash_warn("Not authorized")
      redirect_to root_path and return
    end
  end

  # Flash helper methods to standardize tiers: pass/info/warn/error
  def flash_pass(msg)
    flash[:pass] = msg
    flash[:notice] = msg
    flash[:success] = msg
  end

  def flash_info(msg)
    flash[:info] = msg
  end

  def flash_warn(msg)
    flash[:warn] = msg
    flash[:warning] = msg
    flash[:alert] = msg
  end

  def flash_error(msg)
    flash[:error] = msg
    flash[:alert] = msg
    flash[:danger] = msg
  end

  private

  def ensure_shop_enabled
    unless feature_enabled?(:shop) || current_user&.admin?
      redirect_to root_path and return
    end
  end

  def ensure_asset_project_enabled
    if feature_enabled?(:disable_asset_project) && !current_user&.admin?
      flash_warn("Asset projects are disabled.")
      redirect_to root_path and return
    end
  end

  def asset_project_enabled?
    !feature_enabled?(:disable_asset_project) || current_user&.admin?
  end

  def warn_if_app_url_mismatch
    app_url = ENV.fetch("APP_URL", "http://localhost:3000")
    begin
      app_uri = URI(app_url)
      if app_uri.host != request.host || app_uri.port != request.port
        Rails.logger.warn("APP_URL (#{app_url}) differs from request host (#{request.base_url}). Set APP_URL to #{request.base_url} to avoid OmniAuth CSRF/session issues.")
      end
    rescue => e
      Rails.logger.warn("Invalid APP_URL: #{e.message}")
    end
  end

  def load_charm_slots
    # used by layout to render the current user's charm slot loadout. we set
    # this for every request so that the value is available anywhere the
    # header is rendered (which includes pages that aren't served by
    # CharmSlotsController). without this the instance variable will be nil and
    # the _loadout partial will blow up in production (see recent deploys).
    if logged_in?
      # query directly to bypass User#charm_slots attribute
      @charm_slots = CharmSlot.where(user: current_user).includes(:order)
    else
      @charm_slots = []
    end
  end

  def handle_record_not_unique(exception)
    msg = exception.message.to_s
    # If this appears to be the 'duplicate pending order' unique index, try to find the existing pending order and redirect
    if msg.include?("orders.user_id, orders.product_id") || msg.match?(/orders.*user_id.*product_id/)
      prod_id = params[:product_id] || params.dig(:order, :product_id)
      if prod_id.present? && current_user
        existing = current_user.orders.find_by(product_id: prod_id, status: "pending")
        if existing
          flash_pass("Order already placed")
          redirect_to existing and return
        end
      end
    end

    # Not handled above — re-raise for visibility
    raise exception
  end
end
