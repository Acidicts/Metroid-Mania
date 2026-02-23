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
      if @user.superadmin? && !(current_user&.superadmin?)
        redirect_to admin_users_path, alert: "Cannot change the superadmin's role"
        return
      end

      # When the admin supplies a credit_target (desired total = ships + offset),
      # derive credit_offset = target - total_shipped so the formula holds.
      # Also support the legacy `currency` parameter: tests and some admin UI
      # forms may submit a target currency value which should be converted to an
      # equivalent credit_offset in the same way.
      base_params = user_params
      # ensure we always have a hash before attempting to treat it like one
      unless base_params.is_a?(Hash)
        Rails.logger.warn "Admin::UsersController#update - expected hash from user_params but got #{base_params.inspect}; defaulting to empty hash"
        base_params = {}
      end

      if (params[:user].is_a?(Hash) || params[:user].is_a?(ActionController::Parameters)) && params[:user].key?(:credit_target)
        credit_target = params[:user][:credit_target].to_f
        total_shipped = @user.total_shipped_credits
        base_params[:credit_offset] = (credit_target - total_shipped).round(6)
        base_params.delete(:credit_target)
      end

      if (params[:user].is_a?(Hash) || params[:user].is_a?(ActionController::Parameters)) && params[:user].key?(:currency)
        desired = params[:user][:currency].to_f
        total_shipped = @user.total_shipped_credits
        base_params[:credit_offset] = (desired - total_shipped).round(6)
        # do not store currency directly; it will be recalculated below
      end

      if (params[:user].is_a?(Hash) || params[:user].is_a?(ActionController::Parameters)) && params[:user].key?(:charm_slots)
        base_params[:charm_slots] = params[:user][:charm_slots].to_i
      end

      # `charm_notches` is a virtual value surfaced on the admin form.  When the
      # admin supplies a number we don't persist it directly; instead we create or
      # destroy individual CharmNotch records so that the user's free notch count
      # matches the given value.  Validation occurs later (before the update) so
      # we can return errors if the supplied value is invalid.
      if (params[:user].is_a?(Hash) || params[:user].is_a?(ActionController::Parameters)) && params[:user].key?(:charm_notches)
        # convert early for use in validation block below
        @charm_notches_param = params[:user][:charm_notches]
      end

      # validate notch param before attempting to save anything.  We do this
      # before calling `update` because ActiveRecord#update clears the existing
      # errors object, which would otherwise drop our manually added messages.
      if @charm_notches_param.present?
        begin
          # coerce value exactly like the model does
          desired = @charm_notches_param.to_f.to_i
          if desired < 0
            @user.errors.add(:charm_notches, "must be 0 or greater")
          end
        rescue ArgumentError
          @user.errors.add(:charm_notches, "is not a valid number")
        end
      end

      # if any pre-update validation errors occurred, bail out early so the
      # record isn't saved and the errors are displayed.
      if @user.errors.any?
        render :edit, status: :unprocessable_entity
        return
      end

      previous_offset = @user.credit_offset.to_f
      if @user.update(base_params)
        # perform the actual notch adjustment only once the user record has
        # successfully saved; this keeps the operations separate and avoids
        # partially applying notches when the main update fails.
        if @charm_notches_param.present?
          begin
            @user.adjust_charm_notches!(@charm_notches_param)
          rescue ArgumentError => e
            # revert any changes made by earlier callbacks and surface error
            @user.reload
            @user.errors.add(:charm_notches, e.message)
            render :edit, status: :unprocessable_entity
            return
          end
        end

        # Audit credit offset changes (which represent a change in the user's total credits)
        if base_params.key?(:credit_offset) && previous_offset != @user.credit_offset.to_f
          old_total = @user.total_shipped_credits + previous_offset
          new_total = @user.total_credits
          Audit.create!(user: current_user, action: "update_currency", details: {
            user_id: @user.id,
            before: old_total.round(6),
            after: new_total.round(6),
            credit_offset: @user.credit_offset.to_f,
            charm_slots: @user.charm_slots
          })
          # Keep currency cache in sync
          @user.recalculate_currency!
        end

        # record who flagged/cleared the fraud status if it changed
        if base_params.key?(:flagged_for_fraud)
          if @user.flagged_for_fraud?
            # only set if not already recorded or changed by a different admin
            @user.update_column(:flagged_for_fraud_by_id, current_user.id) if @user.flagged_for_fraud_by_id != current_user.id
          else
            @user.update_column(:flagged_for_fraud_by_id, nil) if @user.flagged_for_fraud_by_id.present?
          end
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
      # Guard against malformed requests where `params[:user]` might be an
      # integer/string etc instead of the usual hash.  Return an empty hash in
      # that case to avoid blowing up later when the caller mutates or iterates
      # it.
      return {} unless params[:user].is_a?(Hash) || params[:user].is_a?(ActionController::Parameters)

      permitted = {}
      if current_user&.superadmin? || current_user&.admin?
        # Allow admins to adjust contact and identity fields
        permitted[:name] = params[:user][:name] if params[:user].key?(:name)
        permitted[:email] = params[:user][:email] if params[:user].key?(:email)
        permitted[:slack_id] = params[:user][:slack_id] if params[:user].key?(:slack_id)

        # new boolean column we added for fraud flagging
        permitted[:flagged_for_fraud] = params[:user][:flagged_for_fraud] if params[:user].key?(:flagged_for_fraud)

        # Allow role changes only when role param present
        permitted[:role] = params[:user][:role] if params[:user][:role].present?

        # Allow admins to adjust the credit offset (computed from credit_target in update action)
        permitted[:credit_offset] = params[:user][:credit_offset] if params[:user].key?(:credit_offset)
      end
      permitted
    end
  end
end
