class AddressesController < ApplicationController
  before_action :require_login
  skip_before_action :ensure_user_setup

  def new
    @address = Address.new(user: current_user)
  end

  def create
    raw_params = address_params
    reload = raw_params.delete(:reload).to_s == "true"
    @address = Address.new(user: current_user, **raw_params.to_h)
    if @address.save
      display = "#{@address.address_line_1}, #{@address.city}, #{@address.province}"
      respond_to do |format|
        format.json { render json: { success: true, id: @address.id, display: display, reload: reload }, status: :ok }
        format.html {
          flash_pass("Address saved successfully.")
          if reload
            redirect_back fallback_location: root_path
          else
            redirect_back fallback_location: root_path
          end
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
    @address = current_user.address || Address.new(user: current_user)
  end

  def update
    raw_params = address_params
    reload = raw_params.delete(:reload).to_s == "true"
    @address = current_user.address || Address.new(user: current_user)
    if @address.update(raw_params)
      display = "#{@address.address_line_1}, #{@address.city}, #{@address.province}"
      respond_to do |format|
        format.json { render json: { success: true, id: @address.id, display: display, reload: reload }, status: :ok }
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

  def destroy
    @address = current_user.address.find(params[:id])
    @address.destroy
    respond_to do |format|
      format.json { render json: { success: true }, status: :ok }
      format.html {
        flash_pass("Address deleted.")
        redirect_back fallback_location: root_path
      }
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
      :country,
      :reload
    )
  end
end
