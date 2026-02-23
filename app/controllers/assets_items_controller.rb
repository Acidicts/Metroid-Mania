class AssetsItemsController < ApplicationController
  before_action :require_login, except: %i[ index show ]
  before_action :set_assets_item, only: %i[ show edit update destroy ]
  before_action :ensure_user_not_fraudulent, only: %i[ index show ]

  # GET /assets_items or /assets_items.json
  def index
    @assets_items = AssetsItem.all
    redirect_to projects_path and return
  end

  # GET /assets_items/1 or /assets_items/1.json
  def show
  end

  # GET /assets_items/new
  # GET /assets_projects/:assets_project_id/assets_items/new
  def new
    @assets_item = AssetsItem.new
    # When nested under an AssetsProject, prefill the project_id so the form can hide the field
    @assets_item.project_id = params[:assets_project_id] if params[:assets_project_id].present?
  end

  # GET /assets_items/1/edit
  def edit
  end

  # POST /assets_items or /assets_items.json
  def create
    # Associate with signed-in user (prevents 'User must exist' validation error)
    @assets_item = current_user.assets_items.build(assets_item_params.except(:spritesheet_file))

    # Handle spritesheet file upload via CDN if provided (best-effort)
    if params.dig(:assets_item, :spritesheet_file).present?
      begin
        uploaded = CdnService.upload(params[:assets_item][:spritesheet_file])
        @assets_item.spritesheet_url = uploaded["url"] if uploaded && uploaded["url"]
      rescue => e
        Rails.logger.warn "Spritesheet upload failed during assets_item create: #{e.message}"
        @assets_item.errors.add(:spritesheet_file, "upload failed")
      end
    end

    # Handle audio file attachment via Active Storage if provided
    if params.dig(:assets_item, :audio).present?
      @assets_item.audio.attach(params[:assets_item][:audio])
    end

    respond_to do |format|
      if @assets_item.save
        format.html { redirect_to @assets_item, notice: "Assets item was successfully created." }
        format.json { render :show, status: :created, location: @assets_item }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @assets_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /assets_items/1 or /assets_items/1.json
  def update
    # Handle spritesheet file upload via CDN if provided (best-effort)
    if params.dig(:assets_item, :spritesheet_file).present?
      begin
        uploaded = CdnService.upload(params[:assets_item][:spritesheet_file])
        @assets_item.spritesheet_url = uploaded["url"] if uploaded && uploaded["url"]
      rescue => e
        Rails.logger.warn "Spritesheet upload failed during assets_item update: #{e.message}"
        @assets_item.errors.add(:spritesheet_file, "upload failed")
      end
    end

    # Handle audio file attachment via Active Storage if provided
    if params.dig(:assets_item, :audio).present?
      @assets_item.audio.attach(params[:assets_item][:audio])
    end

    respond_to do |format|
      if @assets_item.update(assets_item_params.except(:spritesheet_file))
        format.html { redirect_to @assets_item, notice: "Assets item was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @assets_item }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @assets_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /assets_items/1 or /assets_items/1.json
  def destroy
    @assets_item.destroy!

    respond_to do |format|
      format.html { redirect_to assets_items_path, notice: "Assets item was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_assets_item
      @assets_item = AssetsItem.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def assets_item_params
      params.expect(assets_item: [ :title, :description, :media_type, :shipped, :project_id, :spritesheet_url ])
    end
end
