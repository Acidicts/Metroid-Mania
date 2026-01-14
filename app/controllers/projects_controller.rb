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
    # Fetch Hackatime stats here if needed, or rely on background job.
    # For now, simplistic approach:
    @project.update_time_from_hackatime!
  end

  # POST /projects/:id/ship - owner requests a ship (creates a request for admin)
  def ship
    unless @project.user == current_user
      redirect_to project_path(@project), alert: "Not authorized"
      return
    end

    # If project already shipped, require a new devlog (created after last approval) before requesting another ship
    if @project.shipped?
      if @project.approved_at.blank? || !@project.devlogs.where('created_at >= ?', @project.approved_at).exists?
        redirect_to project_path(@project), alert: "You need to add a devlog after the last approval before requesting another ship."
        return
      end
    end

    @project.update!(status: 'pending', ship_requested_at: Time.current, shipped: false)
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
    @project = current_user.projects.build(project_params)
    @project.status = 'pending'
    
    # If the user selected a hackatime project, we might want to sync the time immediately
    # @project.update_time_from_hackatime! if @project.valid?

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: "Project was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
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
      if current_user.hackatime_api_key.present?
        service = HackatimeService.new(current_user.hackatime_api_key, slack_id: current_user.slack_id)
        @hackatime_projects = service.get_all_projects
      else
        @hackatime_projects = []
        flash.now[:alert] = "Please link your Hackatime API key in your profile to select projects."
      end
    end

    # Only allow a list of trusted parameters through.
    def project_params
      params.require(:project).permit(:name, :description, :repository_url, :readme_url, :hackatime_id, :status, :total_seconds)
    end
end
