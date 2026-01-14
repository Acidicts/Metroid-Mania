class DevlogsController < ApplicationController
  before_action :set_project
  before_action :set_devlog, only: %i[ show edit update destroy ]

  # GET /projects/:project_id/devlogs
  def index
    @devlogs = @project.devlogs
  end

  # GET /projects/:project_id/devlogs/1
  def show
  end

  # GET /projects/:project_id/devlogs/new
  def new
    @devlog = @project.devlogs.build
    @devlog.log_date = Date.current

    undocumented_seconds = [@project.total_seconds.to_i - @project.total_devlogged_seconds, 0].max
    min_seconds = 15 * 60
    if undocumented_seconds < min_seconds
      redirect_to project_path(@project), alert: "Not enough undocumented time left (minimum 15 minutes required)"
    end
  end

  # GET /projects/:project_id/devlogs/1/edit
  def edit
  end

  # POST /projects/:project_id/devlogs
  def create
    @devlog = @project.devlogs.build(devlog_params)

    # Set log date to today (server-side) since field is removed from the form
    @devlog.log_date = Date.current

    # Automatically set duration to the remaining undocumented time
    undocumented_seconds = [@project.total_seconds.to_i - @project.total_devlogged_seconds, 0].max

    min_seconds = 15 * 60
    if undocumented_seconds < min_seconds
      @devlog.errors.add(:base, "Not enough undocumented time left (minimum 15 minutes required)")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: "Not enough undocumented time left (minimum 15 minutes required)" }, status: :unprocessable_entity }
      end
      return
    end

    @devlog.duration_minutes = undocumented_seconds / 60

    respond_to do |format|
      if @devlog.save
        format.html { redirect_to project_path(@project), notice: "Devlog was successfully created." }
        format.json { render :show, status: :created, location: [@project, @devlog] }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @devlog.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/:project_id/devlogs/1
  def update
    respond_to do |format|
      if @devlog.update(devlog_params)
        format.html { redirect_to project_path(@project), notice: "Devlog was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: [@project, @devlog] }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @devlog.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/:project_id/devlogs/1
  def destroy
    @devlog.destroy!

    respond_to do |format|
      format.html { redirect_to project_path(@project), notice: "Devlog was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_project
      @project = Project.find(params[:project_id])
    end

    def set_devlog
      @devlog = @project.devlogs.find(params[:id])
    end

    def devlog_params
      params.require(:devlog).permit(:title, :content)
    end
end
