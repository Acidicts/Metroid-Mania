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
      # Debug: log existing orders for this user/product (helps diagnose intermittant test failures)
      Rails.logger.debug "ORDERS LOOKUP (before create): #{Order.where(user_id: current_user.id, product_id: @product.id).map { |o| [o.id, o.status] }.inspect }"

      # Direct DB lookup for pending order (avoid association cache)
      existing_pending = Order.find_by(user_id: current_user.id, product_id: @product.id, status: 'pending')
      if existing_pending
        redirect_to existing_pending, notice: "Order already placed"
        return
      end

      # Attempt to create the pending order; handle DB-level uniqueness races explicitly.
      @order = nil
      Order.transaction(requires_new: true) do
        begin
          @order = current_user.orders.create!(product: @product)
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid, SQLite3::ConstraintException => e
          Rails.logger.warn "OrdersController#create (inner): caught #{e.class} - #{e.message.inspect}; attempting to locate existing pending order"
          existing = Order.find_by(user_id: current_user.id, product_id: @product.id, status: 'pending')
          if existing
            redirect_to existing, notice: "Order already placed"
            return
          end

          # otherwise re-raise so outer rescue can handle
          raise
        end
      end

      if @order && @order.persisted?
        redirect_to @order, notice: "Order placed successfully!"
        return
      end

      @order = current_user.orders.build(product: @product)

      if @order.save
        redirect_to @order, notice: "Order placed successfully!"
      else
        # If creation failed due to insufficient funds and there's a denied order for the same product,
        # surface a clearer message so users know a refund may be missing.
        if @order.errors[:base].include?("Insufficient funds") && current_user.orders.exists?(product: @product, status: 'denied')
          redirect_to products_path, alert: "Insufficient funds — a previous denied order exists and may not have been refunded. Contact support if your balance should have been restored."
        else
          redirect_to products_path, alert: @order.errors.full_messages.to_sentence
        end
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid, SQLite3::ConstraintException => e
      Rails.logger.warn "OrdersController#create: caught #{e.class} - #{e.message.inspect}; re-checking for existing pending order"
      # Some DB adapters (SQLite) surface UNIQUE violations differently; treat any 'duplicate' message as the same.
      msg = e.message.to_s
      if msg.include?("UNIQUE constraint failed") || msg.match?(/duplicate/i)
        existing = Order.find_by(user_id: current_user.id, product_id: @product.id, status: 'pending')
        if existing
          redirect_to existing, notice: "Order already placed"
          return
        end
      end

      # If we get here, attempt to surface the original error for debugging
      raise
    rescue ActiveRecord::RecordInvalid => e
      # Save failed due to validation (e.g. insufficient funds). Inspect the invalid record from the exception.
      invalid_order = e.record

      if invalid_order.errors[:base].include?("Insufficient funds") && current_user.orders.exists?(product: @product, status: 'denied')
        redirect_to products_path, alert: "Insufficient funds — a previous denied order exists and may not have been refunded. Contact support if your balance should have been restored."
      else
        redirect_to products_path, alert: invalid_order.errors.full_messages.to_sentence
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find(params[:id])
    end
end
