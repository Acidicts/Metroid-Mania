class RsvpController < ApplicationController
  before_action :ensure_logged_in_for_create, only: [ :create ]

  def index
    @rsvp_count = Rsvp.count
  end

  def new
    @rsvp = Rsvp.new
  end

  def create
    submit_rsvp
  end

  def submit_after_login
    unless logged_in?
      redirect_path = safe_redirect_path(request.fullpath)
      session[:return_to] = redirect_path if redirect_path.present?
      redirect_to hackclub_login_url(redirect_path) and return
    end

    submit_rsvp
  end

  private

  def ensure_logged_in_for_create
    return if logged_in?

    redirect_path = rsvp_submit_after_login_path
    session[:return_to] = redirect_path
    redirect_to hackclub_login_url(redirect_path) and return
  end

  def create_rsvp(slack_id:, name:)
    @rsvp = Rsvp.new(slack_id: slack_id, name: name, user: current_user)
    if @rsvp.save
      redirect_to rsvp_path, notice: "Thanks for RSVPing! We look forward to seeing your game!"
    else
      flash.now[:alert] = "Sorry, there was an error saving your RSVP. Please try again."
      render :new, status: :unprocessable_entity
    end
  end

  def submit_rsvp
    if Rsvp.exists?(user: current_user)
      return redirect_to rsvp_path, notice: "You have already RSVPed. We look forward to seeing your game!"
    end

    create_rsvp(slack_id: current_user&.slack_id, name: current_user&.name)
  end
end
