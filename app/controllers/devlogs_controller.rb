class DevlogsController < ApplicationController
  before_action :set_project
  before_action :set_devlog, only: %i[ show edit update destroy ]
  before_action :ensure_editable, only: %i[ edit update destroy ]
  before_action :ensure_user_not_fraudulent, only: %i[ index show new edit create update destroy ]

  # GET /projects/:project_id/devlogs
  def index
    # Show only user-created devlogs in the main listing (system-generated devlogs are represented by ship/ship-request markers).
    @devlogs = @project.devlogs.where.not(user_id: nil).order(log_date: :desc, created_at: :desc)
    @ships = @project.ships.order(shipped_at: :desc)
    @ship_requests = @project.ship_requests.order(requested_at: :desc)
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
      flash_info("Cannot create a devlog: project time is not set. Link Hackatime or set total time first.")
      redirect_to project_path(@project) and return
    end

    undocumented_seconds = [@project.total_seconds.to_i - @project.total_devlogged_seconds, 0].max
    min_seconds = 15 * 60
    if undocumented_seconds < min_seconds
      flash_info("Not enough undocumented time left (minimum 15 minutes required)")
      redirect_to project_path(@project) and return
    end

    # Store the computed seconds directly
    @devlog.duration_seconds = undocumented_seconds
  end

  # GET /projects/:project_id/devlogs/1/edit
  def edit
  end

  # POST /projects/:project_id/devlogs
  def create
    @devlog = @project.devlogs.build(devlog_params)

    # Record the creator
    @devlog.user = current_user if defined?(current_user)

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
        requested_seconds = params.dig(:devlog, :duration_seconds)&.to_i
        requested_minutes = params.dig(:devlog, :duration_minutes)&.to_i

        if requested_seconds.present?
          if requested_seconds < 15 * 60
            @devlog.errors.add(:duration_seconds, "must be at least 15 minutes")
          end
          @devlog.duration_seconds = [requested_seconds, undocumented_seconds].min
        elsif requested_minutes.present?
          if requested_minutes < 15
            @devlog.errors.add(:duration_minutes, "must be at least 15 minutes")
          end
          cap_minutes = (undocumented_seconds / 60).to_i
          @devlog.duration_seconds = [requested_minutes, cap_minutes].min * 60
        else
          @devlog.duration_seconds = undocumented_seconds
        end
      end
    end

    respond_to do |format|
      if @devlog.errors.empty? && @devlog.save
        puts "DEBUG DevlogsController#create: saved devlog id=#{@devlog.id} duration_seconds=#{@devlog.duration_seconds}"
        format.html { flash_pass("Devlog created"); redirect_to project_path(@project) }
        format.json { render :show, status: :created, location: [@project, @devlog] }
      else
        puts "DEBUG DevlogsController#create: failed to save; errors=#{@devlog.errors.full_messages.inspect} persisted=#{@devlog.persisted?} duration_seconds=#{@devlog.duration_seconds.inspect} undocumented_seconds=#{(@project.total_seconds.to_i - @project.total_devlogged_seconds)}"
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @devlog.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/:project_id/devlogs/1
  def update
    respond_to do |format|
      if @devlog.update(devlog_params)
        format.html { flash_pass("Devlog was successfully updated."); redirect_to project_path(@project), status: :see_other }
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
      format.html { flash_pass("Devlog was successfully destroyed."); redirect_to project_path(@project), status: :see_other }
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

    def ensure_editable
      unless @devlog.editable_by?(current_user)
        respond_to do |format|
          format.html { redirect_to project_path(@project), alert: "You are not permitted to edit this devlog." }
          format.json { render json: { error: "You are not permitted to edit this devlog." }, status: :forbidden }
        end
      end
    end

    def devlog_params
      params.require(:devlog).permit(:title, :content, :duration_minutes, :duration_seconds)
    end
end
