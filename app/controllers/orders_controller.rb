class OrdersController < ApplicationController
  before_action :require_login
  before_action :set_order, only: %i[ show ]

  # GET /orders or /orders.json
  def index
    @orders = current_user.orders.order(created_at: :desc)
  end

  # GET /orders/1 or /orders/1.json
  def show
    unless @order.user == current_user
      redirect_to orders_path, alert: "Not authorized"
    end
  end

  # POST /orders or /orders.json
  def create
    @product = Product.find(params[:product_id])

    begin
      # Prevent duplicate pending orders for same product by same user
      existing = current_user.orders.find_by(product: @product, status: 'pending')
      if existing
        redirect_to existing, notice: "You already have a pending order for this product"
        return
      end

      @order = current_user.orders.build(product: @product)

      if @order.save
        redirect_to @order, notice: "Order placed successfully!"
      else
        redirect_to products_path, alert: @order.errors.full_messages.to_sentence
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid, StandardError => e
      # Some DB adapters (SQLite) may raise different exceptions for UNIQUE constraint violations.
      msg = e.message.to_s
      if msg.include?("UNIQUE constraint failed") || msg.match?(/duplicate/i)
        # In a race condition both requests may attempt to create a pending order.
        # Find the existing pending order and redirect to it.
        existing = current_user.orders.find_by(product: @product, status: 'pending')
        if existing
          redirect_to existing, notice: "Order already placed"
        else
          # If we couldn't find it, re-raise so the error can be investigated
          raise
        end
      else
        raise
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find(params[:id])
    end
end
