class AssetsProjectsController < ApplicationController
  before_action :require_login, except: %i[ index show ]
  before_action :set_assets_project, only: %i[ show edit update destroy ]
  before_action :ensure_asset_project_enabled, except: %i[ index show ]
  before_action :require_admin, only: %i[ index destroy ]

  # GET /assets_projects or /assets_projects.json
  def index
    @assets_projects = AssetsProject.all
    redirect_to projects_path and return
  end

  # GET /assets_projects/1 or /assets_projects/1.json
  def show
    @project = AssetsProject.find(params[:id])
  end

  # GET /assets_projects/new
  def new
    @assets_project = AssetsProject.new
    load_hackatime_projects
  end

  # GET /assets_projects/1/edit
  def edit
    load_hackatime_projects
  end

  # POST /assets_projects or /assets_projects.json
  def create
    @assets_project = current_user.assets_projects.build(assets_project_params.except(:image_file))

    # Handle image file upload via CDN if provided (best-effort)
    if params.dig(:assets_project, :image_file).present?
      begin
        uploaded = CdnService.upload(params[:assets_project][:image_file])
        @assets_project.image_url = uploaded["url"] if uploaded && uploaded["url"]
      rescue => e
        Rails.logger.warn "Image upload failed during assets_project create: #{e.message}"
        @assets_project.errors.add(:image_file, "upload failed")
      end
    end

    respond_to do |format|
      if @assets_project.save
        format.html { redirect_to @assets_project, notice: "Assets project was successfully created." }
        format.json { render :show, status: :created, location: @assets_project }
      else
        load_hackatime_projects
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @assets_project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /assets_projects/1 or /assets_projects/1.json
  def update
    # Handle image file upload via CDN if provided (best-effort)
    if params.dig(:assets_project, :image_file).present?
      begin
        uploaded = CdnService.upload(params[:assets_project][:image_file])
        @assets_project.image_url = uploaded["url"] if uploaded && uploaded["url"]
      rescue => e
        Rails.logger.warn "Image upload failed during assets_project update: #{e.message}"
        @assets_project.errors.add(:image_file, "upload failed")
      end
    end

    respond_to do |format|
      if @assets_project.update(assets_project_params.except(:image_file))
        format.html { redirect_to @assets_project, notice: "Assets project was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @assets_project }
      else
        load_hackatime_projects
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @assets_project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /assets_projects/1 or /assets_projects/1.json
  def destroy
    @assets_project.destroy!

    respond_to do |format|
      format.html { redirect_to assets_projects_path, notice: "Assets project was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_assets_project
      @assets_project = AssetsProject.find(params.expect(:id))
    end

    def load_hackatime_projects
      if current_user.slack_id.present?
        service = HackatimeService.new(slack_id: current_user.slack_id)
        all_projects = service.get_all_projects

        taken = AssetsProject.where.not(id: @assets_project&.id).flat_map(&:hackatime_ids).map(&:to_s)
        @hackatime_projects = all_projects.reject do |p|
          taken.include?(p["name"]) && !(@assets_project && @assets_project.hackatime_ids.map(&:to_s).include?(p["name"]))
        end
        @taken_hackatime_names = taken

        @hackatime_seconds = {}
        @hackatime_projects.each { |p| @hackatime_seconds[p["name"]] = p["seconds"].to_i }

        if @assets_project && @assets_project.hackatime_ids.present?
          stats = service.get_projects
          @assets_project.hackatime_ids.each do |name|
            next if @hackatime_seconds.key?(name)
            seconds = (stats && stats[name]) || service.get_project_stats(name)
            @hackatime_seconds[name] = seconds.to_i
          end
        end
      else
        @hackatime_projects = []
        @taken_hackatime_names = []
      end
    end

    # Only allow a list of trusted parameters through.
    def assets_project_params
      params.expect(assets_project: [ :title, :description, :media_type, :shipped, :repository_url, :readme_url, :image_url, { hackatime_ids: [] } ])
    end
end
