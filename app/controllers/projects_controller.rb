class ProjectsController < ApplicationController
  before_action :require_login, except: [:index, :show]
  before_action :set_project, only: %i[ show edit update destroy ship ]
  before_action :authorize_owner!, only: %i[ edit update destroy ]

  # GET /projects or /projects.json
  def index
    if logged_in?
      @projects = current_user.projects
    else
      @projects = Project.where(status: 'approved')
    end
  end

  # GET /projects/1 or /projects/1.json
  def show
    # Fetch Hackatime stats now so we display up-to-date time
    @project.update_time_from_hackatime!

    # If the project is linked to Hackatime, gather per-project breakdown for display
    if @project.hackatime_targets.present? && @project.user&.slack_id.present?
      service = HackatimeService.new(slack_id: @project.user.slack_id)
      @hackatime_breakdown = @project.hackatime_targets.map do |t|
        { name: t, seconds: service.get_project_stats(t).to_i }
      end
    else
      @hackatime_breakdown = []
    end

    @ships = @project.ships.order(shipped_at: :desc)
  end

  # POST /projects/:id/ship - owner requests a ship (creates a request for admin)
  def ship
    unless @project.user == current_user
      redirect_to project_path(@project), alert: "Not authorized"
      return
    end

    # Only allow requesting a ship when eligible
    unless @project.eligible_for_ship_request?
      redirect_to project_path(@project), alert: "You need at least 15 minutes of devlogged work since creation or last ship to request shipping, and you cannot already have a pending request."
      return
    end

    if @project.status == 'pending'
      redirect_to project_path(@project), alert: "A ship request is already pending."
      return
    end

    @project.update!(status: 'pending', ship_requested_at: Time.current, shipped: false)
    Audit.create!(user: current_user, project: @project, action: 'ship_request', details: { requested_at: Time.current })
    redirect_to project_path(@project), notice: "Ship request submitted and awaiting admin approval"
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
    @project.status = 'pending'

    respond_to do |format|
      if @project.save
        # If user linked Hackatime projects, fetch and sum their times immediately
        @project.update_time_from_hackatime! if @project.hackatime_ids.present?

        format.html { redirect_to @project, notice: "Project was successfully created." }
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

        # Handle image removal request
        if params.dig(:project, :remove_image).present? && @project.image.attached?
          @project.image.purge
        end

        format.html { redirect_to @project, notice: "Project was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        load_hackatime_projects
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @project.destroy!

    respond_to do |format|
      format.html { redirect_to projects_path, notice: "Project was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params[:id])
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
          taken.include?(p['name']) && !(@project && @project.hackatime_ids.map(&:to_s).include?(p['name']))
        end

        @taken_hackatime_names = taken

        # Build a seconds lookup for each project name so the form can display times for selected chips
        @hackatime_seconds = {}
        @hackatime_projects.each do |p|
          @hackatime_seconds[p['name']] = p['seconds'].to_i
        end

        # Ensure we also query any already-selected names that might not be listed in @hackatime_projects
        if @project && @project.hackatime_ids.present?
          (@project.hackatime_ids || []).each do |name|
            next if @hackatime_seconds.key?(name)
            begin
              @hackatime_seconds[name] = service.get_project_stats(name).to_i
            rescue => e
              Rails.logger.debug "Hackatime fetch failed for #{name}: #{e.message}"
              @hackatime_seconds[name] = 0
            end
          end
        end
      else
        @hackatime_projects = []
        @taken_hackatime_names = []
        flash.now[:alert] = "Please link your Hackatime API key in your profile to select projects."
      end
    end

    # Only allow a list of trusted parameters through.
    def project_params
      params.require(:project).permit(:name, :description, :repository_url, :readme_url, :image, :remove_image, :hackatime_id, :status, :total_seconds, hackatime_ids: [])
    end
end
