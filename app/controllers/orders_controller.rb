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
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find(params[:id])
    end
end
