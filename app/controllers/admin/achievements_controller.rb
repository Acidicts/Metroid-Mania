module Admin
  class AchievementsController < Admin::ApplicationController
    before_action :require_admin
    before_action :set_achievement, only: %i[show edit update destroy]

    def index
      @achievements = Achievement.order(:title).includes(:user_achievements)
    end

    def show
    end

    def new
      @achievement = Achievement.new
    end

    def create
      @achievement = Achievement.new(achievement_params)
      if @achievement.save
        redirect_to admin_achievements_path, notice: "Achievement created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @achievement.update(achievement_params)
        redirect_to admin_achievements_path, notice: "Achievement updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Revoke from a single user if revoke_user_id is present
      if params[:revoke_user_id].present?
        @achievement.user_achievements.where(user_id: params[:revoke_user_id]).destroy_all
        redirect_to edit_admin_achievement_path(@achievement), notice: "Achievement revoked from user."
      else
        @achievement.destroy
        redirect_to admin_achievements_path, notice: "Achievement deleted."
      end
    end

    private

    def set_achievement
      @achievement = Achievement.find(params[:id])
    end

    def achievement_params
      # allow optional file upload if javascript is disabled; the before_action will serialize
      permitted = [ :title, :description, :image_url, :requirement_type, :requirement_value ]
      permitted << :image_upload if params.dig(:achievement, :image_upload).present?
      params.require(:achievement).permit(permitted)
    end
  end
end
