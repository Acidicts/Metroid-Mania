class UsersController < ApplicationController
  before_action :require_login
  skip_before_action :ensure_user_setup, only: [ :edit, :update, :setup ]
  before_action :set_user, only: [ :edit, :update ]

  def show
    @user = User.find(params[:id])
    # Load user's projects (exclude deleted) with their ships and devlogs
    # Use select to only load needed fields for better memory efficiency
    @projects = @user.active_projects
                     .includes(:ships, :devlogs)
                     .order(created_at: :desc)

    # Load user's ships including ships with no project (so we can render 'Project removed'), but
    # exclude ships that belong to deleted projects
    # include all ships regardless of project deletion status; the view
    # logic will render a helpful message if the associated project is gone
    @ships = @user.ships
                  .left_joins(:project)
                  .includes(:project)
                  .order(shipped_at: :desc)

    # Load user's devlogs (through their active projects)
    @devlogs = Devlog.joins(:project)
                     .where(projects: { user_id: @user.id, deleted_at: nil })
                     .includes(:project)
                     .order(created_at: :desc)

    # Fetch Slack profile image with caching (if user has slack_id and token is configured)
    if @user.slack_id.present?
      @slack_profile = Rails.cache.fetch("slack_profile_#{@user.slack_id}", expires_in: 1.hour) do
        begin
          profile = SlackService.new.users_info([ @user.slack_id ]).first
          profile.present? ? profile : nil
        rescue => e
          Rails.logger.error("UsersController#show Slack fetch error for #{@user.id}: #{e.message}")
          nil
        end
      end
    end

    # Pre-calculate statistics to avoid repeated calculations in views
    @total_ships_count = @user.ships.joins(:project).where(projects: { deleted_at: nil }).count
  end

  def edit
  end

  def setup
    unless current_user.setup?
      current_user.update!(setup: true)
      flash_pass("Setup complete! Welcome to Metroid Mania!")
    end

    redirect_to new_project_path
  end

  def update
    return unless @user == current_user || current_user.admin?
    if @user.update(user_params)
      respond_to do |format|
        format.html do
          flash_pass("Profile updated successfully.")
          if request.referer.present? && URI.parse(request.referer).path == profile_path
            redirect_to root_path
          else
            redirect_back fallback_location: root_path
          end
        end
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_user
    # Use explicit id when provided (public profiles or admin), otherwise fall back to the signed-in user
    if params[:id].present? && current_user&.admin?
      @user = User.find(params[:id])
    else
      @user = current_user || (raise ActiveRecord::RecordNotFound, "Couldn't find User without an ID")
    end
  end

  def user_params
    params.require(:user).permit(:hackatime_api_key, :font_on, :set_region, :default_address_id, :username)
  end
end
