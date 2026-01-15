module Admin
  class ProjectsController < ApplicationController
    before_action :require_admin
    before_action :set_project, only: [:show, :approve, :reject, :ship, :unship, :set_status, :force_ship]

    def index
      @projects = Project.all
    end

    def show
    end

    def approve
      credits = params[:credits_per_hour].presence

      previous_status = @project.status

      unless @project.eligible_for_admin_ship?
        redirect_back fallback_location: admin_dashboard_path, alert: 'Project cannot be shipped: it needs at least 15 minutes of devlogged work since creation or last ship.'
        return
      end

      # Calculate devlogged seconds since the request (or last ship/creation depending on context)
      baseline = @project.ship_requested_at || @project.shipped_at || @project.created_at
      devlogged_seconds = @project.devlogs.where('created_at >= ?', baseline).sum(:duration_minutes) * 60

      # Approve and mark as shipped; store credit amount if provided
      @project.update!(status: 'shipped', approved_at: Time.current, shipped: true, shipped_at: Time.current, credits_per_hour: credits, ship_requested_at: nil)

      Audit.create!(user: current_user, project: @project, action: 'approve', details: { previous_status: previous_status, credits_per_hour: credits })

      # If credits were provided, award them to the project owner and record an audit
      if credits.present?
        amount = @project.award_credits!(credits, seconds: devlogged_seconds)
        Audit.create!(user: current_user, project: @project, action: 'credit_awarded', details: { amount: amount, rate: credits, hours: (devlogged_seconds.to_f/3600.0) })
      end

      # Record ship snapshot for historical accounting
      Ship.create!(project: @project, user: current_user, shipped_at: Time.current, devlogged_seconds: devlogged_seconds, credits_awarded: credits.present? ? amount : nil)

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

      # Create ship snapshot and mark as shipped
      # If this ship is in response to an owner's request, calculate devlogs since request; otherwise since last ship/creation
      baseline = @project.ship_requested_at || @project.shipped_at || @project.created_at
      devlogged_seconds = @project.devlogs.where('created_at >= ?', baseline).sum(:duration_minutes) * 60

      @project.update!(status: 'shipped', shipped: true, shipped_at: Time.current)
      Ship.create!(project: @project, user: current_user, shipped_at: Time.current, devlogged_seconds: devlogged_seconds)

      Audit.create!(user: current_user, project: @project, action: 'ship', details: { previous_status: @project.status })
      redirect_back fallback_location: admin_dashboard_path, notice: 'Project shipped.'
    end

    # POST /admin/projects/:id/unship
    def unship
      @project.update!(shipped: false)
      Audit.create!(user: current_user, project: @project, action: 'unship', details: {})
      redirect_back fallback_location: admin_dashboard_path, notice: 'Project marked as unshipped.'
    end

    # POST /admin/projects/:id/force_ship
    def force_ship
      baseline = @project.ship_baseline
      devlogged_seconds = @project.devlogs.where('created_at >= ?', baseline).sum(:duration_minutes) * 60

      @project.update!(shipped: true, status: 'shipped', shipped_at: Time.current)
      Ship.create!(project: @project, user: current_user, shipped_at: Time.current, devlogged_seconds: devlogged_seconds, credits_awarded: nil)

      Audit.create!(user: current_user, project: @project, action: 'force_ship', details: {})
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
        @project.update!(status: 'shipped', shipped: true, shipped_at: Time.current, approved_at: Time.current, credits_per_hour: params[:credits_per_hour].presence)
      when 'pending'
        @project.update!(status: 'pending', approved_at: nil, shipped: false, credits_per_hour: params[:credits_per_hour].presence)
      else
        @project.update!(status: new_status, approved_at: nil, shipped: false, credits_per_hour: params[:credits_per_hour].presence)
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
