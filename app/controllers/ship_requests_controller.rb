class ShipRequestsController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :ensure_user_not_fraudulent, only: %i[ index show new create ]

  def index
    @ship_requests = @project.ship_requests.order(requested_at: :desc)
  end

  def show
    @ship_request = @project.ship_requests.find(params[:id])

    # Only the project owner or an admin may view a request.  Owners should be
    # able to see rejected requests too so they can inspect the linked devlog,
    # but everyone else is simply denied.
    unless current_user.admin? || @project.user == current_user
      flash_warn("Not authorized")
      redirect_to project_path(@project) and return
    end

    # Note: we intentionally do *not* redirect owners away from rejected
    # requests; the earlier implementation attempted to do so and was overly
    # complicated, leading to incorrect behavior and test failures.
    pending_ship_requests = ShipRequest.where(status: "pending").order(created_at: :asc).order(requested_at: :desc)
    if pending_ship_requests.any?
      @ship_queue_placement = pending_ship_requests.pluck(:id).index(@ship_request.id) + 1
    end
  end

  # GET /projects/:project_id/ship_requests/new
  def new
    if (@project.user != current_user) && !current_user.admin?
      redirect_to project_path(@project) and flash_warn("Not authorized") and return
    end

    @ship_request = @project.ship_requests.new
  end

  # POST /projects/:project_id/ship_requests
  def create
    unless @project.user == current_user
      flash_warn("Not authorized")
      redirect_to project_path(@project) and return
    end

    if @project.ship_requests.where(status: "pending").exists?
      flash_info("A ship request is already pending for this project.")
      redirect_to project_path(@project) and return
    end

    unless @project.eligible_for_ship_request?
      flash_info("You need at least 15 minutes of devlogged work since creation or last ship to request shipping.")
      redirect_to project_path(@project) and return
    end

    baseline = @project.ship_baseline
    devlogs_to_link = @project.devlogs.where("created_at >= ?", baseline).where(ship_request_id: nil)
    devlogged_seconds = devlogs_to_link.sum(:duration_seconds)

    Challenge.all.validate()
    multiplier = Challenge.where(type: "multiplier", active: true).maximum(:multiplier) || 1.0

    ActiveRecord::Base.transaction do
      req = @project.ship_requests.create!(user: current_user, requested_at: Time.current, devlogged_seconds: devlogged_seconds, status: "pending", multiplier: multiplier)
      devlogs_to_link.update_all(ship_request_id: req.id)

      @project.update!(status: "pending", ship_requested_at: Time.current)
      Audit.create!(user: current_user, project: @project, action: "ship_request", details: { requested_at: req.requested_at, devlogged_seconds: req.devlogged_seconds, multiplier: multiplier })
    end

    flash_pass("Ship request submitted and awaiting admin approval")
    redirect_to project_path(@project)
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
