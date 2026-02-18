module Admin
  class UsersController < Admin::ApplicationController
    before_action :require_admin
    before_action :set_user, only: %i[ show edit update destroy revert_actions ]

    def index
      @users = User.not_system.order(:email)
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

      # When the admin supplies a credit_target (desired total = ships + offset),
      # derive credit_offset = target - total_shipped so the formula holds.
      base_params = user_params
      if params[:user]&.key?(:credit_target)
        credit_target = params[:user][:credit_target].to_f
        total_shipped = @user.total_shipped_credits
        base_params[:credit_offset] = (credit_target - total_shipped).round(6)
        base_params.delete(:credit_target)
      end

      previous_offset = @user.credit_offset.to_f
      if @user.update(base_params)
        # Audit credit offset changes (which represent a change in the user's total credits)
        if base_params.key?(:credit_offset) && previous_offset != @user.credit_offset.to_f
          old_total = @user.total_shipped_credits + previous_offset
          new_total = @user.total_credits
          Audit.create!(user: current_user, action: "update_currency", details: {
            user_id: @user.id,
            before: old_total.round(6),
            after: new_total.round(6),
            credit_offset: @user.credit_offset.to_f
          })
          # Keep currency cache in sync
          @user.recalculate_currency!
        end

        flash_pass("User updated")
        redirect_to admin_users_path
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user.superadmin?
        redirect_to admin_users_path, alert: "Cannot remove the superadmin"
        return
      end

      if @user.system_user?
        redirect_to admin_users_path, alert: "Cannot remove the system placeholder user"
        return
      end

      if @user.anonymize!
        flash_pass("User anonymized (personal data replaced).")
        redirect_to admin_users_path
      else
        redirect_to admin_users_path, alert: "Unable to anonymize user."
      end
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
          p.update!(shipped: false, status: "pending", approved_at: nil)
          p.devlogs.destroy_all
        end
      end

      flash_pass("User actions reverted: orders removed, projects unshipped, devlogs deleted.")
      redirect_to admin_users_path
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    # Only permit role changes when the current user is a superadmin.
    # Returning a plain hash avoids permitting dangerous keys globally.
    def user_params
      permitted = {}
      if params[:user] && (current_user&.superadmin? || current_user&.admin?)
        # Allow admins to adjust contact and identity fields
        permitted[:name] = params[:user][:name] if params[:user].key?(:name)
        permitted[:email] = params[:user][:email] if params[:user].key?(:email)
        permitted[:slack_id] = params[:user][:slack_id] if params[:user].key?(:slack_id)

        # Allow role changes only when role param present
        permitted[:role] = params[:user][:role] if params[:user][:role].present?

        # Allow admins to adjust the credit offset (computed from credit_target in update action)
        permitted[:credit_offset] = params[:user][:credit_offset] if params[:user].key?(:credit_offset)
      end
      permitted
    end
  end
end
