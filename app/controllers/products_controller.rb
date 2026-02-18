class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]
  before_action :require_admin, only: %i[ new edit create update destroy ]
  before_action :ensure_shop_enabled, only: %i[ index ]

  # GET /products or /products.json
  def index
    @products = Product.all
  end

  # GET /products/1 or /products/1.json
  def show
    if !current_user&.admin?
      flash_warn("You do not have permission to view this product.")
      redirect_to products_path and return
    end
  end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit
  end

  # POST /products or /products.json
  def create
    @product = Product.new(product_params)

    # Handle image file upload if provided (best-effort)
    if params.dig(:product, :image_file).present?
      begin
        uploaded = CdnService.upload(params[:product][:image_file])
        @product.image_url = uploaded["url"] if uploaded && uploaded["url"]
      rescue => e
        Rails.logger.warn "Image upload failed during product create: #{e.message}"
        @product.errors.add(:image_url, "upload failed")
      end
    end

    @product.update_price_from_steam!

    respond_to do |format|
      if @product.save
        format.html { flash_pass("Product was successfully created."); redirect_to @product }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1 or /products/1.json
  def update
    # Handle image file upload if provided (best-effort)
    if params.dig(:product, :image_file).present?
      begin
        uploaded = CdnService.upload(params[:product][:image_file])
        @product.image_url = uploaded["url"] if uploaded && uploaded["url"]
      rescue => e
        Rails.logger.warn "Image upload failed during product update: #{e.message}"
        @product.errors.add(:image_url, "upload failed")
      end
    end

    respond_to do |format|
      if @product.update(product_params)
        @product.update_price_from_steam!
        format.html { flash_pass("Product was successfully updated."); redirect_to @product, status: :see_other }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1 or /products/1.json
  def destroy
    @product.destroy!

    respond_to do |format|
      format.html { flash_pass("Product was successfully destroyed."); redirect_to products_path, status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.require(:product).permit(
        :name,
        :description,
        :steam_app_id,
        :price_currency,
        :steam_price_cents,    # allow editing steam price explicitly
        :grant_enabled,        # legacy flag (backwards compatible)
        :link,
        :cost_credits,
        :credits_per_dollar,
        :variable_grant,
        :limited,
        :stock,
        :grant_min_cents,
        :grant_max_cents,
        :grant_min_dollars,    # more intuitive admin input (virtual setter)
        :grant_max_dollars,    # virtual setter
        :grant_amount_cents,
        :grant_amount_dollars,
        :image_url
      )
    end
end
