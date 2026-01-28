class UsersController < ApplicationController
  before_action :require_login, only: [:edit, :update]
  before_action :set_user, only: [:show, :edit, :update]

  def show
    # Load user's projects with their ships and devlogs
    @projects = @user.projects.includes(:ships, :devlogs).order(created_at: :desc)
    
    # Load user's ships (including those from other users' projects if they're the recipient)
    @ships = @user.ships.includes(:project).order(shipped_at: :desc)
    
    # Load user's devlogs (through their projects)
    @devlogs = Devlog.joins(:project).where(projects: { user_id: @user.id }).includes(:project).order(created_at: :desc)

    # Fetch Slack profile image (if user has slack_id and token is configured)
    if @user.slack_id.present?
      begin
        profile = SlackService.new.users_info([@user.slack_id]).first
        @slack_profile = profile if profile.present?
      rescue => e
        Rails.logger.error("UsersController#show Slack fetch error for #{@user.id}: #{e.message}")
        @slack_profile = nil
      end
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to root_path, notice: "Profile updated successfully."
    else
      render :edit
    end
  end

  private

  def set_user
    # Use explicit id when provided (public profiles or admin), otherwise fall back to the signed-in user
    if params[:id].present?
      @user = User.find(params[:id])
    else
      @user = current_user || (raise ActiveRecord::RecordNotFound, "Couldn't find User without an ID")
    end
  end

  def user_params
    params.require(:user).permit(:hackatime_api_key, :font_on)
  end
end
