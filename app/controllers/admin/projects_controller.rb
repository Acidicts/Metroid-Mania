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

      # Approve and mark as shipped; store credit amount if provided
      @project.update!(status: 'approved', approved_at: Time.current, shipped: true, credits_per_hour: credits, ship_requested_at: nil)

      Audit.create!(user: current_user, project: @project, action: 'approve', details: { previous_status: previous_status, credits_per_hour: credits })

      # If credits were provided, award them to the project owner and record an audit
      if credits.present?
        amount = @project.award_credits!(credits)
        Audit.create!(user: current_user, project: @project, action: 'credit_awarded', details: { amount: amount, rate: credits, hours: (@project.total_seconds.to_f/3600.0) })
      end

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
      unless @project.can_be_shipped?
        redirect_back fallback_location: admin_dashboard_path, alert: 'Project cannot be shipped: it must be approved and have at least one devlog created after approval.'
        return
      end

      @project.update!(shipped: true)
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
      @project.update!(shipped: true)
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

      if new_status == 'approved'
        @project.update!(status: 'approved', approved_at: Time.current, shipped: false, credits_per_hour: params[:credits_per_hour].presence)
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
