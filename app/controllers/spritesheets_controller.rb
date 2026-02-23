class SpritesheetsController < ApplicationController
  before_action :require_login
  before_action :set_assets_item
  before_action :set_spritesheet, only: %i[ show edit update destroy download ]
  before_action :ensure_asset_project_enabled
  before_action :ensure_user_not_fraudulent, only => %i[ new create edit update destroy ]

  # GET /assets_items/:assets_item_id/spritesheets/new
  # GET /assets_projects/:assets_project_id/assets_items/:assets_item_id/spritesheets/new
  def new
    @spritesheet = @assets_item.spritesheets.new
  end

  # GET /assets_items/:assets_item_id/spritesheets/1
  def show
  end

  # GET /assets_items/:assets_item_id/spritesheets/1/download
  def download
    # Fetch the file from CDN and stream it to the user (follow redirects).
    # Safely parse/escape URLs that contain spaces or other unsafe characters.
    require "net/http"
    require "uri"

    begin
      raw_url = @spritesheet.url.to_s

      # Try parsing the URL; if it fails, percent-escape unsafe chars and retry
      current_uri = begin
        URI.parse(raw_url)
      rescue URI::InvalidURIError => parse_err
        Rails.logger.warn "Spritesheet URL invalid, escaping and retrying: #{raw_url} (#{parse_err.message})"
        URI.parse(URI::DEFAULT_PARSER.escape(raw_url))
      end

      max_redirects = 5
      response = nil

      (0...max_redirects).each do
        http = Net::HTTP.new(current_uri.host, current_uri.port)
        http.use_ssl = (current_uri.scheme == "https")
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Get.new(current_uri.request_uri)
        resp = http.request(request)

        case resp
        when Net::HTTPSuccess
          response = resp
          break
        when Net::HTTPRedirection
          location = resp["location"]
          Rails.logger.info "Spritesheet download redirected to: #{location}"

          # join may raise if location contains unsafe chars; escape if necessary
          begin
            current_uri = URI.join(current_uri, location)
          rescue URI::InvalidURIError
            Rails.logger.warn "Redirect location invalid, escaping: #{location}"
            current_uri = URI.join(current_uri, URI::DEFAULT_PARSER.escape(location))
          end

          next
        else
          response = resp
          break
        end
      end

      if response.nil?
        Rails.logger.error "Download failed: too many redirects"
        redirect_to [ @assets_item, @spritesheet ], alert: "Failed to download spritesheet (too many redirects)."
        return
      end

      if response.is_a?(Net::HTTPSuccess)
        # Extract filename from the original (escaped) URL when possible
        original_uri = begin
          URI.parse(raw_url)
        rescue URI::InvalidURIError
          URI.parse(URI::DEFAULT_PARSER.escape(raw_url))
        end

        original_path = original_uri.path || ""
        url_filename = File.basename(original_path)
        filename = @spritesheet.name.parameterize + File.extname(url_filename)

        send_data response.body,
          filename: filename,
          type: response.content_type || "image/png",
          disposition: "attachment"
      else
        Rails.logger.error "Download failed: HTTP #{response.code}"
        redirect_to [ @assets_item, @spritesheet ], alert: "Failed to download spritesheet (HTTP #{response.code})."
      end
    rescue => e
      Rails.logger.error "Download failed: #{e.class} #{e.message}"
      Rails.logger.debug e.backtrace.join("\n")
      redirect_to [ @assets_item, @spritesheet ], alert: "Failed to download spritesheet."
    end
  end

  # POST /assets_items/:assets_item_id/spritesheets or /assets_items/:assets_item_id/spritesheets.json
  def create
    @spritesheet = @assets_item.spritesheets.build(spritesheet_params.except(:file))

    # Handle file upload via CDN if provided (best-effort)
    if params.dig(:spritesheet, :file).present?
      begin
        uploaded = CdnService.upload(params[:spritesheet][:file])
        @spritesheet.url = uploaded["url"] if uploaded && uploaded["url"]
      rescue => e
        Rails.logger.warn "Spritesheet upload failed during create: #{e.message}"
        @spritesheet.errors.add(:file, "upload failed")
      end
    end

    respond_to do |format|
      if @spritesheet.save
        format.html { redirect_to @assets_item, notice: "Spritesheet was successfully created." }
        format.json { render :show, status: :created, location: [ @assets_item, @spritesheet ] }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @spritesheet.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /spritesheets/1 or /spritesheets/1.json
  def update
    # Handle file upload via CDN if provided (best-effort)
    if params.dig(:spritesheet, :file).present?
      begin
        uploaded = CdnService.upload(params[:spritesheet][:file])
        @spritesheet.url = uploaded["url"] if uploaded && uploaded["url"]
      rescue => e
        Rails.logger.warn "Spritesheet upload failed during update: #{e.message}"
        @spritesheet.errors.add(:file, "upload failed")
      end
    end

    respond_to do |format|
      if @spritesheet.update(spritesheet_params.except(:file))
        format.html { redirect_to @assets_item, notice: "Spritesheet was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: [ @assets_item, @spritesheet ] }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @spritesheet.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /spritesheets/1 or /spritesheets/1.json
  def destroy
    @spritesheet.destroy!

    respond_to do |format|
      format.html { redirect_to @assets_item, notice: "Spritesheet was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_assets_item
      asset_item_id = params[:assets_item_id]
      if asset_item_id.blank?
        redirect_to assets_items_path, alert: "Asset ID is missing."
        return
      end
      @assets_item = AssetsItem.find(asset_item_id)
    rescue ActiveRecord::RecordNotFound
      redirect_to assets_items_path, alert: "Asset not found."
    end

    def set_spritesheet
      @spritesheet = @assets_item.spritesheets.find(params[:id])
    end

    def spritesheet_params
      params.require(:spritesheet).permit(:name, :url, :file)
    end
end
