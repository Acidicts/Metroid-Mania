class DevlogsController < ApplicationController
  before_action :set_project
  before_action :set_devlog, only: %i[ show edit update destroy ]

  # GET /projects/:project_id/devlogs
  def index
    @devlogs = @project.devlogs.order(created_at: :desc)
    @ships = @project.ships.order(shipped_at: :desc)
  end

  # GET /projects/:project_id/devlogs/1
  def show
  end

  # GET /projects/:project_id/devlogs/new
  def new
    @devlog = @project.devlogs.build
    @devlog.log_date = Date.current

    # Always use remaining undocumented time for duration; project must have total_seconds set
    if @project.total_seconds.blank?
      redirect_to project_path(@project), alert: "Cannot create a devlog: project time is not set. Link Hackatime or set total time first."
      return
    end

    undocumented_seconds = [@project.total_seconds.to_i - @project.total_devlogged_seconds, 0].max
    min_seconds = 15 * 60
    if undocumented_seconds < min_seconds
      redirect_to project_path(@project), alert: "Not enough undocumented time left (minimum 15 minutes required)"
      return
    end

    @devlog.duration_minutes = undocumented_seconds / 60
  end

  # GET /projects/:project_id/devlogs/1/edit
  def edit
  end

  # POST /projects/:project_id/devlogs
  def create
    @devlog = @project.devlogs.build(devlog_params)

    # Set log date to today (server-side)
    @devlog.log_date = Date.current

    # Project must have a total_seconds value and we auto-calc duration from remaining undocumented time
    if @project.total_seconds.blank?
      @devlog.errors.add(:base, "Project time not set; cannot create devlog")
    else
      undocumented_seconds = [@project.total_seconds.to_i - @project.total_devlogged_seconds, 0].max
      min_seconds = 15 * 60
      if undocumented_seconds < min_seconds
        @devlog.errors.add(:base, "Not enough undocumented time left (minimum 15 minutes required)")
      else
        # Allow optional requested duration (e.g., tests or API clients). Cap to remaining undocumented time.
        requested = params.dig(:devlog, :duration_minutes)&.to_i
        if requested.present?
          if requested < 15
            @devlog.errors.add(:duration_minutes, "must be at least 15 minutes")
          end
          cap_minutes = (undocumented_seconds / 60).to_i
          @devlog.duration_minutes = [requested, cap_minutes].min
        else
          @devlog.duration_minutes = undocumented_seconds / 60
        end
      end
    end

    respond_to do |format|
      if @devlog.errors.empty? && @devlog.save
        puts "DEBUG DevlogsController#create: saved devlog id=#{@devlog.id} duration=#{@devlog.duration_minutes}"
        format.html { redirect_to project_path(@project) }
        format.json { render :show, status: :created, location: [@project, @devlog] }
      else
        puts "DEBUG DevlogsController#create: failed to save; errors=#{@devlog.errors.full_messages.inspect} persisted=#{@devlog.persisted?} duration=#{@devlog.duration_minutes.inspect} undocumented_seconds=#{(@project.total_seconds.to_i - @project.total_devlogged_seconds)}"
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
      params.require(:devlog).permit(:title, :content, :duration_minutes)
    end
end
