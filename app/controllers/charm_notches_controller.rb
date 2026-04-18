class CharmNotchesController < ApplicationController
  before_action :set_charm_notch, only: %i[ show edit update destroy ]
  before_action :ensure_user_not_fraudulent, only: %i[ index show ]
  before_action :require_login_for_donate, only: %i[ donate ]

  # GET /charm_notches or /charm_notches.json
  def index
    @charm_notches = CharmNotch.all
  end

  # GET /charm_notches/1 or /charm_notches/1.json
  def show
  end

  # GET /charm_notches/new
  def new
    @charm_notch = CharmNotch.new
  end

  # GET /charm_notches/1/edit
  def edit
  end

  # POST /charm_notches/donate/:user_id
  # accepts a `user_id` route parameter identifying the recipient of the donation.
  # Designed to be invoked via `button_to` from the user profile page.
  def donate
    @user = User.find(params[:user_id])

    available_notches = current_user.charm_notches.where(charm_slot_id: nil)
    if available_notches.empty?
      flash_warn("You have no available charm notches to donate.")
      redirect_to user_profile_path(@user) and return
    end

    available_notches.first.update!(user: @user)
    flash_pass("Charm notch donated successfully!")
    Audit.create!(action: "donate_charm_notch", user: current_user, details: { recipient_id: @user.id })
    redirect_to user_profile_path(@user)
  end

  # POST /charm_notches or /charm_notches.json
  def create
    @charm_notch = CharmNotch.new(charm_notch_params)

    respond_to do |format|
      if @charm_notch.save
        format.html { redirect_to @charm_notch, notice: "Charm notch was successfully created." }
        format.json { render :show, status: :created, location: @charm_notch }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @charm_notch.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /charm_notches/1 or /charm_notches/1.json
  def update
    respond_to do |format|
      if @charm_notch.update(charm_notch_params)
        format.html { redirect_to @charm_notch, notice: "Charm notch was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @charm_notch }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @charm_notch.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /charm_notches/1 or /charm_notches/1.json
  def destroy
    @charm_notch.destroy!

    respond_to do |format|
      format.html { redirect_to charm_notches_path, notice: "Charm notch was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def require_login_for_donate
      return if logged_in?

      flash_warn("You must be logged in to donate charm notches")
      redirect_to root_path and return
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_charm_notch
      @charm_notch = CharmNotch.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def charm_notch_params
      params.expect(charm_notch: [ :user_id, :charm_slot_id ])
    end
end
