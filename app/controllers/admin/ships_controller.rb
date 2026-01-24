module Admin
  class ShipsController < Admin::ApplicationController
    before_action :require_admin
    before_action :set_ship, only: [:show, :edit, :update]
    before_action :ensure_ship_has_project, only: [:show, :edit, :update]

    def index
      @ships = Ship.includes(:project, :user).order(shipped_at: :desc).limit(100)
    end

    def show
    end

    def edit
    end

    def update
      # permit editing these fields
      permitted = params.require(:ship).permit(:devlogged_seconds, :credits_awarded, :shipped_at, :credits_per_hour, :recalculate)

      # optionally recalculate credits based on credits_per_hour param or project's rate
      if permitted[:recalculate].present? && permitted[:recalculate].to_s != '0'
        rate = permitted[:credits_per_hour].presence || @ship.project.credits_per_hour
        if rate.present?
          secs = (permitted[:devlogged_seconds].presence || @ship.devlogged_seconds).to_f
          computed = rate.to_f * (secs / 3600.0)
          # compute float and round to 2 decimal places for currency
          permitted[:credits_awarded] = computed.round(6)
        end
      end

      # compute currency delta before persisting
      old_credits = @ship.credits_awarded.to_f
      new_credits = permitted[:credits_awarded].present? ? permitted[:credits_awarded].to_f : old_credits
      credits_delta = new_credits - old_credits

      # Only update real ship attributes (avoid passing through credits_per_hour/recalculate unknown attrs)
      attrs = {}
      attrs[:devlogged_seconds] = permitted[:devlogged_seconds] if permitted[:devlogged_seconds].present?
      attrs[:credits_awarded] = new_credits if permitted[:credits_awarded].present?
      attrs[:shipped_at] = permitted[:shipped_at] if permitted[:shipped_at].present?

      ActiveRecord::Base.transaction do
        @ship.update!(attrs)

        if credits_delta != 0.0
          owner = @ship.project.user
          owner.update!(currency: (owner.currency || 0) + credits_delta)
          Audit.create!(user: current_user, project: @ship.project, action: 'adjust_ship_credits', details: { ship_id: @ship.id, delta: credits_delta, new_credits: new_credits })
        end

        Audit.create!(user: current_user, project: @ship.project, action: 'update_ship', details: { ship_id: @ship.id, changes: attrs })
      end

      redirect_to admin_ship_path(@ship), notice: 'Ship updated.'
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    private

    def set_ship
      @ship = Ship.find(params[:id])
    end

    def ensure_ship_has_project
      return if @ship&.project.present?

      redirect_to admin_ships_path, alert: "Related project not found for Ship ##{@ship.id}"
    end
  end
end
