module Admin
  class SessionsController < Admin::ApplicationController
    # Allow admins to sign in via email/password
    skip_before_action :verify_authenticity_token, only: :create

    def new
      if auto_admin_enabled?
        admin = find_or_create_dev_admin
        session[:user_id] = admin.id
        Rails.logger.info("[auto_admin] signed in #{admin.email}") if Rails.env.development? || Rails.env.test?
        flash[:notice] = "Auto-signed in as #{admin.email} (development only)"
        # show the generated password in development logs and flash so the developer can inspect it
        if (pw = session.delete(:__auto_admin_password))
          Rails.logger.info("[auto_admin] password for #{admin.email}: #{pw}")
          flash[:notice] = "#{flash[:notice]} — password: #{pw}"
        end

        redirect_to(admin_root_path) rescue redirect_to(root_path) and return
      end
    end

    def create
      user = User.find_by(email: params[:email])
      if user&.authenticate(params[:password]) && user.admin?
        session[:user_id] = user.id
        redirect_to admin_dashboard_path, notice: "Signed in as admin"
      else
        flash.now[:alert] = "Invalid credentials or not an admin"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session[:user_id] = nil
      redirect_to root_path, notice: "Signed out"
    end

    private

    def auto_admin_enabled?
      # If AUTO_ADMIN is explicitly set, honor its boolean value ("1","true","yes" => true; "0","false","no" => false).
      # Otherwise fall back to enabling in development/test environments by default.
      val = ENV['AUTO_ADMIN']&.to_s&.strip
      return ActiveModel::Type::Boolean.new.cast(val) unless val.nil? || val == ''

      Rails.env.development? || Rails.env.test?
    end

    def find_or_create_dev_admin
      email = ENV.fetch('AUTO_ADMIN_EMAIL', 'admin@example.dev')
      pw    = ENV['AUTO_ADMIN_PASSWORD'].to_s.strip.presence || SecureRandom.base58(16)

      user = User.find_by(email: email)
      if user
        # If a known password is provided via env, ensure the existing user can be accessed with it
        if ENV['AUTO_ADMIN_PASSWORD'].present? && user.respond_to?(:password=)
          user.password = pw
          user.password_confirmation = pw if user.respond_to?(:password_confirmation=)
          # persist even if validations would block (dev convenience)
          user.save!(validate: false) rescue nil
        end

        # expose the password one-request-only in dev/test for visibility
        session[:__auto_admin_password] = pw if Rails.env.development? || Rails.env.test?
        return user
      end

      attrs = { email: email, name: 'Admin' }
      attrs[:admin] = true if User.column_names.include?('admin')
      attrs[:role]  = 'admin' if User.column_names.include?('role')

      user = User.new(attrs)
      user.password = pw if user.respond_to?(:password=)
      user.password_confirmation = pw if user.respond_to?(:password_confirmation=)
      user.confirmed_at = Time.current if user.respond_to?(:confirmed_at=)

      begin
        user.save!
      rescue ActiveRecord::RecordInvalid
        user.save!(validate: false)
      end

      session[:__auto_admin_password] = pw
      user
    end
  end
end
