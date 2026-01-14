module Admin
  class SessionsController < ApplicationController
    # Allow admins to sign in via email/password
    skip_before_action :verify_authenticity_token, only: :create

    def new
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
  end
end
