class ShipRequestsController < ApplicationController
  before_action :require_login
  before_action :set_project

  def index
    @ship_requests = @project.ship_requests.order(requested_at: :desc)
  end

  def show
    @ship_request = @project.ship_requests.find(params[:id])
  end

  # POST /projects/:project_id/ship_requests
  def create
    unless @project.user == current_user
      redirect_to project_path(@project), alert: "Not authorized"
      return
    end

    if @project.ship_requests.where(status: 'pending').exists?
      redirect_to project_path(@project), alert: "A ship request is already pending for this project."
      return
    end

    unless @project.eligible_for_ship_request?
      redirect_to project_path(@project), alert: "You need at least 15 minutes of devlogged work since creation or last ship to request shipping."
      return
    end

    baseline = @project.ship_baseline
    devlogs_to_link = @project.devlogs.where('created_at >= ?', baseline).where(ship_request_id: nil)
    devlogged_seconds = devlogs_to_link.sum(:duration_minutes) * 60

    ActiveRecord::Base.transaction do
      req = @project.ship_requests.create!(user: current_user, requested_at: Time.current, devlogged_seconds: devlogged_seconds, status: 'pending')
      devlogs_to_link.update_all(ship_request_id: req.id)

      @project.update!(status: 'pending', ship_requested_at: Time.current)
      Audit.create!(user: current_user, project: @project, action: 'ship_request', details: { requested_at: req.requested_at, devlogged_seconds: req.devlogged_seconds })
    end

    redirect_to project_path(@project), notice: "Ship request submitted and awaiting admin approval"
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
