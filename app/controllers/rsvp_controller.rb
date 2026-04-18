class RsvpController < ApplicationController
  skip_before_action :ensure_user_setup

  def index
    @rsvp_count = Rsvp.count
  end

  def new
    @rsvp = Rsvp.new
  end

  def create
    if logged_in?
      submit_signed_in_rsvp
    else
      submit_guest_rsvp
    end
  end

  def submit_after_login
    unless logged_in?
      redirect_path = safe_redirect_path(request.fullpath)
      session[:return_to] = redirect_path if redirect_path.present?
      redirect_to hackclub_login_url(redirect_path) and return
    end

    submit_signed_in_rsvp
  end

  private

  def create_rsvp(slack_id:, name:, user: nil)
    @rsvp = Rsvp.new(slack_id: slack_id, name: name, user: user)
    if @rsvp.save
      redirect_to rsvp_path, notice: "Thanks for RSVPing! We look forward to seeing your game!"
    else
      flash.now[:alert] = "Sorry, there was an error saving your RSVP. Please try again."
      render :new, status: :unprocessable_entity
    end
  end

  def submit_signed_in_rsvp
    if Rsvp.exists?(user: current_user)
      return redirect_to rsvp_path, notice: "You have already RSVPed. We look forward to seeing your game!"
    end

    create_rsvp(slack_id: current_user&.slack_id, name: current_user&.name, user: current_user)
  end

  def submit_guest_rsvp
    create_rsvp(slack_id: rsvp_params[:slack_id], name: rsvp_params[:name])
  end

  def rsvp_params
    params.fetch(:rsvp, {}).permit(:name, :slack_id)
  end
end
