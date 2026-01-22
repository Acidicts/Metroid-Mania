class OrdersController < ApplicationController
  before_action :require_login
  before_action :set_order, only: %i[ show ]

  # GET /orders or /orders.json
  def index
    @orders = current_user.orders.order(created_at: :desc)
  end

  # GET /orders/new?product_id=1
  def new
    @product = Product.find_by(id: params[:product_id])
    if @product
      @order = current_user.orders.build(product: @product)
    else
      @order = current_user.orders.build
    end
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
      puts "DEBUG ORDERS LOOKUP (before create): #{Order.where(user_id: current_user.id, product_id: @product.id).map { |o| [o.id, o.status] }.inspect }"
      Rails.logger.debug "ORDERS LOOKUP (before create): #{Order.where(user_id: current_user.id, product_id: @product.id).map { |o| [o.id, o.status] }.inspect }"

      # Direct DB lookup for pending order (avoid association cache).
      # Use the DB-backed enum value when available (some adapters store an integer in the DB).
      pending_db_val = if Order.respond_to?(:statuses)
        Order.statuses['pending']
      elsif Order.const_defined?(:STATUS_VALUE_MAP)
        Order::STATUS_VALUE_MAP['pending']
      else
        'pending'
      end

      puts "DEBUG OrdersController#create: pending_db_val=#{pending_db_val.inspect} (class=#{pending_db_val.class})"
      existing_pending = Order.find_by(user_id: current_user.id, product_id: @product.id, status: pending_db_val)
      puts "DEBUG OrdersController#create: existing_pending=#{existing_pending&.id.inspect} status=#{existing_pending&.status.inspect}"
      if existing_pending
        redirect_to existing_pending, notice: "Order already placed"
        return
      end

      puts "DEBUG OrdersController#create: current_user.currency=#{current_user.currency.inspect} product.price_currency=#{@product.price_currency.inspect}"

      # Attempt to create the pending order; handle DB-level uniqueness races explicitly.
      @order = nil
      begin
        puts "DEBUG OrdersController#create: about to create order (user_id=#{current_user.id} product_id=#{@product.id} status=#{pending_db_val.inspect})"

        order_attrs = { product: @product, status: pending_db_val }
        # Accept a user-selected grant amount (dollars) for variable products
        if @product.variable_grant? && params[:grant_amount_dollars].present?
          # store cents on the order model
          order_attrs[:grant_amount_cents] = (params[:grant_amount_dollars].to_f * 100).round
        end

        @order = current_user.orders.create!(order_attrs)
        puts "DEBUG OrdersController#create: create! returned; order_id=#{@order&.id.inspect} persisted=#{@order&.persisted?.inspect} errors=#{@order&.errors&.full_messages.inspect}"
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid, SQLite3::ConstraintException => e
        Rails.logger.warn "OrdersController#create: caught #{e.class} - #{e.message.inspect}; attempting to locate existing pending order"
        existing = Order.find_by(user_id: current_user.id, product_id: @product.id, status: pending_db_val)
        if existing
          redirect_to existing, notice: "Order already placed"
          return
        end

        # otherwise re-raise so outer rescue can handle
        raise
      end

      if @order && @order.persisted?
        redirect_to @order, notice: "Order placed successfully!"
        return
      else
        @order = current_user.orders.build(product: @product, status: pending_db_val)

        # If creation failed due to insufficient funds and there's a denied order for the same product,
        # surface a clearer message so users know a refund may be missing.
        if @order.errors[:base].include?("Insufficient funds") && current_user.orders.exists?(product: @product, status: (Order.respond_to?(:statuses) ? Order.statuses['denied'] : (Order.const_defined?(:STATUS_VALUE_MAP) ? Order::STATUS_VALUE_MAP['denied'] : 'denied')))
          redirect_to products_path, alert: "Insufficient funds — a previous denied order exists and may not have been refunded. Contact support if your balance should have been restored."
        else
          redirect_to products_path, alert: @order.errors.full_messages.to_sentence
        end
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid, SQLite3::ConstraintException => e
      puts "DEBUG OrdersController#create: outer rescue caught #{e.class} - #{e.message.inspect}"
      Rails.logger.warn "OrdersController#create: caught #{e.class} - #{e.message.inspect}; re-checking for existing pending order"
      # Some DB adapters (SQLite) surface UNIQUE violations differently; treat any 'duplicate' message as the same.
      msg = e.message.to_s
      if msg.include?("UNIQUE constraint failed") || msg.match?(/duplicate/i)
        existing = Order.find_by(user_id: current_user.id, product_id: @product.id, status: pending_db_val)
        if existing
          redirect_to existing, notice: "Order already placed"
          return
        end
      end

      # If we get here, attempt to surface the original error for debugging
      raise
    rescue ActiveRecord::RecordInvalid => e
      puts "DEBUG OrdersController#create: RecordInvalid: #{e.record.errors.full_messages.inspect}"
      # Save failed due to validation (e.g. insufficient funds). Inspect the invalid record from the exception.
      invalid_order = e.record

      if invalid_order.product_id == @product.id
        # re-render the checkout page with the invalid order so users can fix the input
        @order = invalid_order
        render :new, status: :unprocessable_entity
      elsif invalid_order.errors[:base].include?("Insufficient funds") && current_user.orders.exists?(product: @product, status: (Order.respond_to?(:statuses) ? Order.statuses['denied'] : (Order.const_defined?(:STATUS_VALUE_MAP) ? Order::STATUS_VALUE_MAP['denied'] : 'denied')))
        redirect_to products_path, alert: "Insufficient funds — a previous denied order exists and may not have been refunded. Contact support if your balance should have been restored."
      else
        redirect_to products_path, alert: invalid_order.errors.full_messages.to_sentence
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find_by_param(params[:id])
    end
end
