class AddressesController < ApplicationController
  before_action :require_login
  skip_before_action :ensure_user_setup

  def new
    @address = current_user.build_address
  end

  def create
    @address = current_user.build_address(address_params)
    if @address.save
      respond_to do |format|
        format.json { render json: { success: true }, status: :ok }
        format.html {
          flash_pass("Address saved successfully.")
          redirect_back fallback_location: root_path
        }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @address.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @address = current_user.address || current_user.build_address
  end

  def update
    @address = current_user.address || current_user.build_address
    if @address.update(address_params)
      respond_to do |format|
        format.json { render json: { success: true }, status: :ok }
        format.html {
          flash_pass("Address updated successfully.")
          redirect_back fallback_location: root_path
        }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @address.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  private

  def address_params
    params.require(:address).permit(
      :address_line_1,
      :address_line_2,
      :city,
      :province,
      :postal_code,
      :country
    )
  end
end
