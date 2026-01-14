module Admin
  class OrdersController < ApplicationController
    before_action :require_admin
    before_action :set_order, only: [:show, :fulfill, :decline]

    def index
      @orders = Order.order(created_at: :desc)
    end

    def show
    end

    def fulfill
      if @order.shipped?
        redirect_back fallback_location: admin_orders_path, alert: 'Order already fulfilled.'
        return
      end

      previous = @order.status
      @order.update!(status: 'shipped')
      Audit.create!(user: current_user, project: nil, action: 'order_fulfilled', details: { order_id: @order.id, previous_status: previous })
      redirect_back fallback_location: admin_orders_path, notice: 'Order marked as fulfilled.'
    end

    def decline
      if @order.denied?
        redirect_back fallback_location: admin_orders_path, alert: 'Order already declined.'
        return
      end

      previous = @order.status
      @order.update!(status: 'denied')

      # Refund user (only if the order had a cost)
      if @order.cost.present? && @order.cost.to_f > 0
        @order.user.update!(currency: (@order.user.currency || 0) + @order.cost.to_f)
        Audit.create!(user: current_user, project: nil, action: 'order_refunded', details: { order_id: @order.id, amount: @order.cost.to_f, previous_status: previous })
      else
        Audit.create!(user: current_user, project: nil, action: 'order_declined', details: { order_id: @order.id, previous_status: previous })
      end

      redirect_back fallback_location: admin_orders_path, notice: 'Order declined and user refunded.'
    end

    private

    def set_order
      @order = Order.find(params[:id])
    end
  end
end
