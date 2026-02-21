class CharmSlotsController < ApplicationController
  before_action :set_charm_slot, only: %i[ show edit update destroy ]
  # require_login is handled in index when accessing user-specific slots

  # GET /charm_slots or /charm_slots.json
  # If the current user is an admin we display every slot; otherwise we
  # render the user's own slots (this used to live in a separate `loadout`
  # action which was exposed as a route, but we now keep it internal only).
  def index
    if logged_in? && !admin?
      @charm_slots = current_user.charm_slots.includes(:order)
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
