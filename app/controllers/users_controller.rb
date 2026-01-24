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
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:hackatime_api_key)
  end
end
