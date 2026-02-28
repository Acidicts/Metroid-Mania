class WishlistsController < ApplicationController
  before_action :set_wishlist, only: %i[ show edit update destroy ]
  before_action :require_admin, except: [ :index, :show, :add_product, :remove_product ]
  before_action :require_login

  # GET /wishlists or /wishlists.json
  def index
    @wishlists = Wishlist.all
  end

  # GET /wishlists/1 or /wishlists/1.json
  def show
  end

  # GET /wishlists/new
  def new
    @wishlist = Wishlist.new
  end

  # GET /wishlists/1/edit
  def edit
  end

  # POST /wishlists/:id/add_product
  # expects a `product_id` parameter.  We don't render a template, since the
  # button on the product card submits the form remotely via Turbo.  Returning a
  # bare 204 keeps the client happy without needing extra behavior.
  def add_product
    @wishlist = Wishlist.find(params[:id])
    @wishlist.product_ids << params.require(:product_id)
    @wishlist.save!

    respond_to do |format|
      format.turbo_stream do
        # must use helpers.dom_id in controller context
        render turbo_stream: turbo_stream.replace(helpers.dom_id(@wishlist),
          partial: "wishlists/wishlist", locals: { wishlist: @wishlist })
      end
      # for ordinary HTML visits we want to refresh the page so the user
      # sees the updated list; a simple redirect back to the referring page
      # or the products index keeps the UX reasonable when Turbo isn't
      # intercepting (Turbo Drive is disabled in this project).
      format.html { redirect_back fallback_location: products_path }
      # other formats (JSON, API clients) continue to get a 204 to keep
      # existing expectations in place.
      format.any { head :no_content }
    end
  end

  # POST /wishlists/:id/remove_product
  # similarly expects `product_id` and returns 204.
  def remove_product
    @wishlist = Wishlist.find(params[:id])
    @wishlist.product_ids.delete(params.require(:product_id))
    @wishlist.save!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(helpers.dom_id(@wishlist),
          partial: "wishlists/wishlist", locals: { wishlist: @wishlist })
      end
      format.html { redirect_back fallback_location: products_path }
      format.any { head :no_content }
    end
  end

  # POST /wishlists or /wishlists.json
  def create
    @wishlist = Wishlist.new(wishlist_params)

    respond_to do |format|
      if @wishlist.save
        format.html { redirect_to @wishlist, notice: "Wishlist was successfully created." }
        format.json { render :show, status: :created, location: @wishlist }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @wishlist.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /wishlists/1 or /wishlists/1.json
  def update
    respond_to do |format|
      if @wishlist.update(wishlist_params)
        format.html { redirect_to @wishlist, notice: "Wishlist was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @wishlist }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @wishlist.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /wishlists/1 or /wishlists/1.json
  def destroy
    @wishlist.destroy!

    respond_to do |format|
      format.html { redirect_to wishlists_path, notice: "Wishlist was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_wishlist
      @wishlist = Wishlist.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def wishlist_params
    # permit user_id and an array of product ids (empty arrays are allowed)
    params.expect(wishlist: [ :user_id, product_ids: [] ])
    end
end

