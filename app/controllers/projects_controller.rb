class ProjectsController < ApplicationController
  before_action :require_login, except: [ :index, :show ]
  before_action :set_project, only: %i[ show edit update destroy ship ]
  before_action :authorize_owner!, only: %i[ edit update destroy ]
  before_action :ensure_user_not_fraudulent, only: %i[ edit update ship ]

  # GET /projects or /projects.json
  def index
    # Require login for the projects index — redirect anonymous users to the home page.
    unless logged_in?
      redirect_to home_path, flash: { warn: "Please sign in to view projects." } and return
    end

    # start with the user's active projects; if a `q` param is present,
    # apply more sophisticated filtering.
    # we also need to look at associated user display names and the
    # project's single tag (the new dropdown-based tagging system).
    # include user association for eager loading and join for searching
    @projects = current_user.active_projects
                     .includes(:user)
                     .left_joins(:user, :project_tag)

    if params[:q].present?
      raw = params[:q].to_s.strip
      if raw.start_with?("#")
        # exact tag match when prefixed with '#'
        tagname = raw[1..].downcase
        @projects = @projects.where("LOWER(project_tags.tag_string) = ?", tagname)
      else
        q = raw.downcase
        # case-insensitive exact-match redirect
        if Project.where("LOWER(name) = ?", q).any?
          p = Project.where("LOWER(name) = ?", q).first

          redirect_to project_path(p) and return
        end

        # otherwise treat as a substring search across project name and owner
        @projects = @projects.where("LOWER(projects.name) LIKE :q OR LOWER(users.name) LIKE :q", q: "%#{q}%")
      end
    end

    @assets = current_user.assets_projects.includes(:user)
    @enabled = asset_project_enabled?
  end

  # GET /projects/1 or /projects/1.json
  def show
    # If the project is linked to Hackatime, gather per-project breakdown for display
    if @project.hackatime_targets.present? && @project.user&.slack_id.present?
      service = HackatimeService.new(slack_id: @project.user.slack_id)
      stats = service.get_projects
      @hackatime_breakdown = @project.hackatime_targets.map do |t|
        { name: t, seconds: stats[t].to_i }
      end

      # Persist a fresh total_seconds only if it changed (avoids unnecessary updates)
      total = @hackatime_breakdown.sum { |p| p[:seconds].to_i }
      @project.update(total_seconds: total) if total > 0 && @project.total_seconds.to_i != total
    else
      @hackatime_breakdown = []
    end

    # Eager load associations to prevent N+1 queries
    @ships = @project.ships.includes(:user).order(shipped_at: :desc)
    @ship_requests = @project.ship_requests.includes(:user, :processed_by).order(requested_at: :desc)
  end

  # POST /projects/:id/ship - owner requests a ship (creates a request for admin)
  def ship
    # Backwards-compat: `projects#ship` will now create a ShipRequest so older links still work.
    unless @project.user == current_user
      flash_warn("Not authorized")
      redirect_to project_path(@project) and return
    end

    # Delegate to the new ShipRequests flow
    baseline = @project.ship_baseline
    if @project.ship_requests.where(status: "pending").exists?
      flash_info("A ship request is already pending.")
      redirect_to project_path(@project) and return
    end

    unless @project.eligible_for_ship_request?
      flash_info("You need at least 15 minutes of devlogged work since creation or last ship to request shipping.")
      redirect_to project_path(@project) and return
    end

    devlogs_to_link = @project.devlogs.where("created_at >= ?", baseline).where(ship_request_id: nil)
    devlogged_seconds = devlogs_to_link.sum(:duration_seconds)

    ActiveRecord::Base.transaction do
      req = @project.ship_requests.create!(user: current_user, requested_at: Time.current, devlogged_seconds: devlogged_seconds, status: "pending")
      devlogs_to_link.update_all(ship_request_id: req.id)

      @project.update!(status: "pending", ship_requested_at: Time.current, shipped: false)
      Audit.create!(user: current_user, project: @project, action: "ship_request", details: { requested_at: req.requested_at, devlogged_seconds: req.devlogged_seconds })
    end

    flash_pass("Ship request submitted and awaiting admin approval")
    redirect_to project_path(@project)
  end

  # GET /projects/new
  def new
    @project = current_user.projects.build
    load_hackatime_projects
  end

  # GET /projects/1/edit
  def edit
    load_hackatime_projects
  end

  # POST /projects or /projects.json
  def create
    # Normalize hackatime_ids param (ensure empty array when not provided)
    if params[:project] && !params[:project].key?(:hackatime_ids)
      params[:project][:hackatime_ids] = []
    end

    @project = current_user.projects.build(project_params)
    @project.status = "unshipped"

    respond_to do |format|
      if @project.save
        # If user linked Hackatime projects, fetch and sum their times immediately
        @project.update_time_from_hackatime! if @project.hackatime_ids.present?

        format.html { flash_pass("Project was successfully created."); redirect_to @project }
        format.json { render :show, status: :created, location: @project }
      else
        load_hackatime_projects
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    # Normalize hackatime_ids param: if user cleared all selections the param will be missing; treat as empty array
    if params[:project] && !params[:project].key?(:hackatime_ids)
      params[:project][:hackatime_ids] = []
    end

    respond_to do |format|
      if @project.update(project_params)
        # If hackatime_ids were provided or present, refresh total_seconds
        @project.update_time_from_hackatime! if @project.hackatime_ids.present?

        # Handle image removal request (use detach to avoid variant-record SQL on minimal test DBs)
        if params.dig(:project, :remove_image).present? && @project.image.attached?
          @project.image.detach
        end

        format.html { flash_pass("Project was successfully updated."); redirect_to @project, status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        load_hackatime_projects
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    # Soft-delete ownership deletion: reclaim awarded credits and zero out ships similar to admin deletion behavior
    Project.transaction do
      owner = @project.user
      total_awarded = @project.ships.sum(:credits_awarded).to_f

      @project.ships.find_each do |s|
        s.update!(credits_awarded: 0, devlogged_seconds: 0)
      end

      if total_awarded > 0 && owner.present?
        owner.update!(currency: (owner.currency || 0) - total_awarded)
      end

      # Soft-delete without running validations so we can clear metadata (including hackatime links)
      @project.update_columns(deleted_at: Time.current, status: "deleted", name: "Deleted Project", hackatime_ids: nil)

      Audit.create!(user: current_user, project: @project, action: "delete", details: { reclaimed_credits: total_awarded })
    end

    respond_to do |format|
      format.html { flash_pass("Project was successfully deleted."); redirect_to projects_path }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find_by(id: params[:id])

      # If the project wasn't found, redirect to index with a friendly message
      unless @project
        flash_warn("Project not found.")
        redirect_to projects_path and return
      end

      # If the project is soft-deleted, block access unless admin or the owner
      if @project.deleted? && !(admin? || (current_user && current_user == @project.user))
        flash_warn("Project not found.")
        redirect_to projects_path and return
      end
    end

    def authorize_owner!
      unless @project.user == current_user || admin?
        redirect_to projects_path, alert: "Not authorized"
      end
    end

    def load_hackatime_projects
      if current_user.slack_id.present?
        service = HackatimeService.new(slack_id: current_user.slack_id)
        all_projects = service.get_all_projects

        # Determine hackatime projects already taken by other projects to avoid duplicate linking
        taken = Project.where.not(id: @project&.id).flat_map(&:hackatime_ids).map(&:to_s)

        # Provide available projects for selection (exclude taken ones) but keep current project's selections available
        @hackatime_projects = all_projects.reject do |p|
          taken.include?(p["name"]) && !(@project && @project.hackatime_ids.map(&:to_s).include?(p["name"]))
        end

        @taken_hackatime_names = taken

        # Build a seconds lookup for each project name so the form can display times for selected chips
        @hackatime_seconds = {}
        @hackatime_projects.each do |p|
          @hackatime_seconds[p["name"]] = p["seconds"].to_i
        end

        # Ensure we also query any already-selected names that might not be listed in @hackatime_projects
        if @project && @project.hackatime_ids.present?
          stats = service.get_projects
          (@project.hackatime_ids || []).each do |name|
            next if @hackatime_seconds.key?(name)
            # Prefer the bulk `get_projects` result but fall back to `get_project_stats`
            # so tests that stub the per-project method work correctly.
            seconds = (stats && stats[name]) || service.get_project_stats(name)
            @hackatime_seconds[name] = seconds.to_i
          end
        end
      else
        @hackatime_projects = []
        @taken_hackatime_names = []
        flash.now[:info] = "Please link your Hackatime API key in your profile to select projects."
      end
    end

    # Only allow a list of trusted parameters through.
    def project_params
      # `remove_image` is handled explicitly in the controller (it is NOT a model attribute).
      permitted = [ :name, :description, :repository_url, :readme_url, :image, :hackatime_id, :status, :total_seconds, :project_tag_id, { hackatime_ids: [] } ]
      # only admin users may set featured flag via the form
      permitted << :featured if current_user&.admin?
      pp = params.require(:project).permit(*permitted)

      # Defensive: if an empty/blank `image` value was submitted (some clients/JS may send ''),
      # remove the key so `update` does not unintentionally replace/detach the existing attachment.
      pp.delete(:image) if pp.key?(:image) && pp[:image].blank?

      pp
    end
end
