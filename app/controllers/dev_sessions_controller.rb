class DevSessionsController < ApplicationController
  # Only available in development and test
  before_action :allow_dev_only

  def create
    email = params[:email]
    user = User.find_by(email: email)
    if user
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
