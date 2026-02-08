module Admin
  class ShipRequestsController < Admin::ApplicationController
    before_action :require_admin
    before_action :set_ship_request, only: [:show, :approve, :reject]

    def index
      # Exclude ship requests that belong to deleted projects
      @ship_requests = ShipRequest.joins(:project).where(projects: { deleted_at: nil }).order(requested_at: :desc)
    end

    def show
      @users = User.order(:name)

      # Sync multiplier data between request and associated ship on page load so admin sees consistent values
      begin
        @ship_request.sync_multiplier_with_ship
      rescue => e
        Rails.logger.error("Failed to sync multiplier on ShipRequest show ##{@ship_request.id}: #{e.message}")
      end
    end

    def approve
      credits = params[:credits_per_hour].presence || @ship_request.credits_per_hour || @ship_request.project.credits_per_hour
      recipient_user_id = params[:recipient_user_id].presence
      multiplier = params[:multiplier].presence

      # Persist any admin-supplied multiplier on the request before approving so it gets carried to the Ship
      if multiplier.present?
        @ship_request.update!(multiplier: multiplier)
      end

      if @ship_request.pending?
        ship = @ship_request.approve!(admin_user: current_user, credits_per_hour: credits, recipient_user_id: recipient_user_id)
        Audit.create!(user: current_user, project: @ship_request.project, action: 'approve_ship_request', details: { ship_request_id: @ship_request.id, credits_per_hour: credits, recipient_user_id: recipient_user_id, multiplier: multiplier, ship_id: ship.id })
        redirect_back fallback_location: admin_ship_requests_path, notice: 'Ship request approved and shipped.'
      else
        redirect_back fallback_location: admin_ship_requests_path, alert: 'Ship request is not pending.'
      end
    end

    def reject
      if @ship_request.pending?
        @ship_request.reject!(admin_user: current_user)
        @ship_request.project.update!(status: 'rejected', ship_requested_at: nil)
        Audit.create!(user: current_user, project: @ship_request.project, action: 'reject_ship_request', details: { ship_request_id: @ship_request.id })
        redirect_back fallback_location: admin_ship_requests_path, notice: 'Ship request rejected.'
      else
        redirect_back fallback_location: admin_ship_requests_path, alert: 'Ship request is not pending.'
      end
    end

    private

    def set_ship_request
      @ship_request = ShipRequest.find(params[:id])
      if @ship_request.project.deleted?
        redirect_back fallback_location: admin_ship_requests_path, alert: 'Ship request belongs to a deleted project.'
      end
    end
  end
end