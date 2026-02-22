class CharmSlotsController < ApplicationController
  before_action :set_charm_slot, only: %i[ show edit update destroy ]
  # require_login is handled in index when accessing user-specific slots

  # GET /charm_slots or /charm_slots.json
  # If the current user is an admin we display every slot; otherwise we
  # render the user's own slots (this used to live in a separate `loadout`
  # action which was exposed as a route, but we now keep it internal only).
  def index
    if logged_in? && !admin?
      # avoid collision with the `charm_slots` integer column on User
      @charm_slots = CharmSlot.where(user: current_user).includes(:order)
    else
      @charm_slots = CharmSlot.all
    end
  end

  # GET /charm_slots/1 or /charm_slots/1.json
  def show
  end

  # GET /charm_slots/new
  def new
    @charm_slot = CharmSlot.new
  end

  # GET /charm_slots/1/edit
  def edit
  end

  # POST /charm_slots or /charm_slots.json
  def create
    @charm_slot = CharmSlot.new(charm_slot_params)

    respond_to do |format|
      if @charm_slot.save
        format.html { redirect_to @charm_slot, notice: "Charm slot was successfully created." }
        format.json { render :show, status: :created, location: @charm_slot }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @charm_slot.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /charm_slots/submit or /charm_slots/submit/:user_id
  # This action transitions all of the given user's pending slots to `submitted`.
  # The user parameter is provided via the route, but for security we only allow
  # the current user unless an admin is performing the action.
  def submit
    user = if admin? && params[:user_id].present?
             User.find(params[:user_id])
    else
             current_user
    end

    # iterate slots that have an order pending approval
    user.charm_slots.includes(:order).where.not(order_id: nil).find_each do |slot|
      if slot.order&.status == "pending"
        slot.order.status = "submitted"
        slot.order.save!
      end
    end

    respond_to do |format|
      format.html { redirect_to charm_slots_path, notice: "Loadout submitted successfully." }
      format.json { head :no_content }
    end
  end

  def remove
    # load early so we can inspect it for authorization and status checks
    @charm_slot = CharmSlot.find(params[:id])

    # only allow the owner or an admin to change a slot
    unless (current_user && current_user.charm_slots.exists?(id: @charm_slot.id)) || admin?
      redirect_to charm_slots_path and flash_warn("You are not Authorised to do this") and return
    end

    # cannot remove if slot has already moved past pending state
    if @charm_slot.order.nil? || @charm_slot.order.status != "pending"
      redirect_to charm_slots_path and flash_warn("This Charm Is already submitted dm @Alex if you have any issues") and return
    end

    # mark the associated order as cancelled and clear ownership
    @charm_slot.order.update!(status: "user_denied")
    @charm_slot.update!(order_id: nil)
    @charm_slot.charm_notches.update_all(charm_slot_id: nil)

    # respond similarly to other mutating actions
    respond_to do |format|
      format.html { redirect_to charm_slots_path, notice: "Charm slot was successfully cleared.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # PATCH/PUT /charm_slots/1 or /charm_slots/1.json
  def update
    respond_to do |format|
      if @charm_slot.update(charm_slot_params)
        format.html { redirect_to @charm_slot, notice: "Charm slot was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @charm_slot }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @charm_slot.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /charm_slots/1 or /charm_slots/1.json
  def destroy
    unless (current_user && @charm_slot.user == current_user) || admin?
      redirect_to charm_slots_path and flash_warn("You are not Authorised to do this") and return
    end

    @charm_slot.destroy!

    respond_to do |format|
      format.html { redirect_to charm_slots_path, notice: "Charm slot was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_charm_slot
      id = params.expect(:id)
    # Prevent accidental lookup of the old `loadout` path; redirect to index instead.
    if id.to_s == "loadout" || id.to_s !~ /\A\d+\z/
      redirect_to charm_slots_path and return
    end

    @charm_slot = CharmSlot.find(id)
    end

    # Only allow a list of trusted parameters through.
    def charm_slot_params
      params.expect(charm_slot: [ :user_id, :order_id ])
    end
end
