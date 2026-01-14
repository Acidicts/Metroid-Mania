module Admin
  class UsersController < ApplicationController
    before_action :require_admin
    before_action :set_user, only: %i[ show edit update destroy revert_actions ]

    def index
      @users = User.order(:email)
    end

    def show
    end

    def edit
    end

    def update
      if @user.superadmin?
        redirect_to admin_users_path, alert: "Cannot change the superadmin's role"
        return
      end

      if @user.update(user_params)
        redirect_to admin_users_path, notice: "User updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user.superadmin?
        redirect_to admin_users_path, alert: "Cannot remove the superadmin"
        return
      end

      @user.destroy!
      redirect_to admin_users_path, notice: "User deleted"
    end

    # POST /admin/users/:id/revert_actions
    def revert_actions
      if @user.superadmin?
        redirect_to admin_users_path, alert: "Cannot revert actions for the superadmin"
        return
      end

      ActiveRecord::Base.transaction do
        # Remove all orders by user
        @user.orders.destroy_all

        # For each project owned by the user: unship, reset status to pending, clear approved_at, remove devlogs
        @user.projects.find_each do |p|
          p.update!(shipped: false, status: 'pending', approved_at: nil)
          p.devlogs.destroy_all
        end
      end

      redirect_to admin_users_path, notice: "User actions reverted: orders removed, projects unshipped, devlogs deleted."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:role)
    end
  end
end
