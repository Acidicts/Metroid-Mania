module Admin
  class ProjectsController < Admin::ApplicationController
    before_action :require_admin
    before_action :set_project, only: [:show, :approve, :reject, :ship, :unship, :set_status, :force_ship, :destroy]
    # Prevent acting on projects that have been soft-deleted
    before_action :ensure_not_deleted, only: [:show, :approve, :reject, :ship, :unship, :set_status, :force_ship]

    def index
      @projects = Project.active.where.not(name: "Deleted Project").order(created_at: :desc)
    end

    def show
    end

    def approve
      credits = params[:credits_per_hour].presence || @project.credits_per_hour

      previous_status = @project.status

      unless @project.eligible_for_admin_ship?
        redirect_back fallback_location: admin_dashboard_path, alert: 'Project cannot be shipped: it needs at least 15 minutes of devlogged work since creation or last ship.'
        return
      end

      # If there is a pending ShipRequest, approve that instead (preserves linked devlogs)
      pending_request = @project.ship_requests.where(status: 'pending').order(requested_at: :asc).first

      if pending_request
        ship = pending_request.approve!(admin_user: current_user, credits_per_hour: params[:credits_per_hour].presence || pending_request.credits_per_hour)
        @project.update!(status: 'shipped', approved_at: Time.current, shipped: true, shipped_at: Time.current, ship_requested_at: nil)
        Audit.create!(user: current_user, project: @project, action: 'approve', details: { previous_status: previous_status, credits_per_hour: params[:credits_per_hour].presence || pending_request.credits_per_hour, ship_request_id: pending_request.id, ship_id: ship.id })
        redirect_back fallback_location: admin_dashboard_path, notice: 'Ship request approved and marked as shipped.'
        return
      end

      # Fallback: no pending ShipRequest found — preserve previous behavior (compute devlogs since baseline)
      baseline = @project.ship_requested_at || @project.shipped_at || @project.created_at
      devlogged_seconds = @project.devlogs.where('created_at >= ?', baseline).sum(:duration_seconds)
      # treat zero as absent so model can fall back to `total_seconds`
      devlogged_seconds = nil if devlogged_seconds.to_i <= 0

      # Approve and mark as shipped. Only persist a new rate when explicitly supplied (don't wipe existing rate).
      attrs = { status: 'shipped', approved_at: Time.current, shipped: true, shipped_at: Time.current, ship_requested_at: nil }
      attrs[:credits_per_hour] = params[:credits_per_hour].presence if params[:credits_per_hour].present?
      @project.update!(attrs)

      Audit.create!(user: current_user, project: @project, action: 'approve', details: { previous_status: previous_status, credits_per_hour: credits })

      # Log computed values to stdout before awarding credits to help debug award failures
      puts "DEBUG Admin::ProjectsController#approve: computed credits=#{credits.inspect} params_credits=#{params[:credits_per_hour].inspect} baseline=#{baseline.inspect} devlogged_seconds=#{devlogged_seconds.inspect} project_total_seconds=#{@project.total_seconds.inspect}"

      # Atomically award credits (when provided) and create the Ship snapshot
      ship = @project.ship_and_award_credits!(admin_user: current_user, rate: credits, devlogged_seconds: devlogged_seconds, shipped_at: Time.current)

      puts "DEBUG Admin::ProjectsController#approve: ship created id=#{ship.id} devlogged_seconds=#{ship.devlogged_seconds.inspect} credits_awarded=#{ship.credits_awarded.inspect} owner_currency_after=#{@project.user.reload.currency.inspect}"

      redirect_back fallback_location: admin_dashboard_path, notice: 'Project approved and marked as shipped.'
    end

    def reject
      previous_status = @project.status
      @project.update!(status: 'rejected', shipped: false, approved_at: nil, ship_requested_at: nil)

      Audit.create!(user: current_user, project: @project, action: 'reject', details: { previous_status: previous_status })

      redirect_back fallback_location: admin_dashboard_path, notice: 'Project rejected.'
    end

    # POST /admin/projects/:id/ship
    def ship
      unless @project.eligible_for_admin_ship?
        redirect_back fallback_location: admin_dashboard_path, alert: 'Project cannot be shipped: it needs at least 15 minutes of devlogged work since creation or last ship.'
        return
      end

      # Create ship snapshot and mark as shipped; award credits when the project has a rate.
      # If this ship is in response to an owner's request, calculate devlogs since request; otherwise since last ship/creation
      baseline = @project.ship_requested_at || @project.shipped_at || @project.created_at
      devlogged_seconds = @project.devlogs.where('created_at >= ?', baseline).sum(:duration_seconds)
      # treat zero as absent so model can fall back to `total_seconds`
      devlogged_seconds = nil if devlogged_seconds.to_i <= 0

      credits = @project.credits_per_hour
      @project.update!(status: 'shipped', approved_at: Time.current, shipped: true, shipped_at: Time.current)

      # Use the model method which atomically creates the Ship row and awards credits (no-ops if rate is nil).
      @project.ship_and_award_credits!(admin_user: current_user, rate: credits, devlogged_seconds: devlogged_seconds, shipped_at: Time.current)

      Audit.create!(user: current_user, project: @project, action: 'ship', details: { previous_status: @project.status, credits_per_hour: credits })
      redirect_back fallback_location: admin_dashboard_path, notice: 'Project shipped.'
    end

    # POST /admin/projects/:id/unship
    def unship
      @project.update!(shipped: false, status: 'unshipped', shipped_at: nil)
      Audit.create!(user: current_user, project: @project, action: 'unship', details: {})
      redirect_back fallback_location: admin_dashboard_path, notice: 'Project marked as unshipped.'
    end

    def destroy
      # Soft-delete: set deleted_at, mark status, and anonymize name/hackatime ids.
      # Also zero out ship records (devlogged_seconds and credits_awarded) and refund any
      # awarded credits from the project owner so accounting remains consistent.
      Project.transaction do
        owner = @project.user

        total_awarded = @project.ships.sum(:credits_awarded).to_f

        # Zero out ships related to this project
        @project.ships.find_each do |s|
          s.update!(credits_awarded: 0, devlogged_seconds: 0)
        end

        # Refund owner's currency by subtracting previously awarded amount
        if total_awarded > 0 && owner.present?
          owner.update!(currency: (owner.currency || 0) - total_awarded)
        end

        # Anonymize and clear hackatime linkage so others can use those ids
        # Use update_columns to bypass validations so soft-delete always succeeds
        @project.update_columns(deleted_at: Time.current, status: 'deleted', name: 'Deleted Project', hackatime_ids: nil)

        Audit.create!(user: current_user, project: @project, action: 'delete', details: { reclaimed_credits: total_awarded })
      end

      redirect_back fallback_location: admin_dashboard_path, notice: 'Project deleted.'
    end

    def ensure_not_deleted
      return unless @project.deleted?
      redirect_back fallback_location: admin_projects_path, alert: 'Project has been deleted.'
    end

    # POST /admin/projects/:id/force_ship
    def force_ship
      baseline = @project.ship_baseline
      devlogged_seconds = @project.devlogs.where('created_at >= ?', baseline).sum(:duration_seconds)
      # treat zero as absent so model can fall back to `total_seconds`
      devlogged_seconds = nil if devlogged_seconds.to_i <= 0

      # Determine credits: prefer explicit param, fall back to existing project rate
      supplied_credits = params[:credits_per_hour].presence || params["credits_for_#{@project.id}"].presence
      credits = supplied_credits || @project.credits_per_hour

      # If admin supplied a new rate, persist it
      if params[:credits_per_hour].present?
        previous_credits = @project.credits_per_hour
        @project.update!(credits_per_hour: params[:credits_per_hour].presence)
        Audit.create!(user: current_user, project: @project, action: 'set_credits', details: { previous_credits: previous_credits, credits_per_hour: params[:credits_per_hour].presence })
      end

      # Mark project as shipped and create the Ship snapshot (award credits inside)
      @project.update!(status: 'shipped', shipped: true, shipped_at: Time.current, credits_per_hour: credits)

      # Atomically create the Ship and award credits when applicable
      @project.ship_and_award_credits!(admin_user: current_user, rate: credits, devlogged_seconds: devlogged_seconds, shipped_at: Time.current)

      Audit.create!(user: current_user, project: @project, action: 'force_ship', details: { credits_per_hour: credits })
      redirect_back fallback_location: admin_dashboard_path, notice: 'Project force-shipped by admin.'
    end

    # POST /admin/projects/:id/set_status
    def set_status
      new_status = params[:status]
      unless Project::STATUSES.include?(new_status)
        redirect_back fallback_location: admin_dashboard_path, alert: "Invalid status"
        return
      end

      previous_status = @project.status

      case new_status
      when 'shipped'
        credits = params[:credits_per_hour].presence || @project.credits_per_hour
        attrs = { status: 'shipped', shipped: true, shipped_at: Time.current, approved_at: Time.current }
        attrs[:credits_per_hour] = params[:credits_per_hour].presence if params[:credits_per_hour].present?
        @project.update!(attrs)

        # award credits when applicable
        baseline = @project.ship_baseline
        devlogged_seconds = @project.devlogs.where('created_at >= ?', baseline).sum(:duration_seconds)
        # treat zero as absent so model can fall back to `total_seconds`
        devlogged_seconds = nil if devlogged_seconds.to_i <= 0
        @project.ship_and_award_credits!(admin_user: current_user, rate: credits, devlogged_seconds: devlogged_seconds, shipped_at: @project.shipped_at || Time.current)

      when 'pending'
        attrs = { status: 'pending', approved_at: nil, shipped: false }
        attrs[:credits_per_hour] = params[:credits_per_hour].presence if params[:credits_per_hour].present?
        @project.update!(attrs)
      else
        attrs = { status: new_status, approved_at: nil, shipped: false }
        attrs[:credits_per_hour] = params[:credits_per_hour].presence if params[:credits_per_hour].present?
        @project.update!(attrs)
      end

      Audit.create!(user: current_user, project: @project, action: 'set_status', details: { previous_status: previous_status, new_status: new_status, credits_per_hour: params[:credits_per_hour].presence })

      redirect_back fallback_location: admin_dashboard_path, notice: "Project status updated to #{new_status}."
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end
  end
end
