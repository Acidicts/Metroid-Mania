class OrdersController < ApplicationController
  before_action :require_login
  before_action :require_admin, only: %i[ admin_new_order admin_force_create ]
  before_action :ensure_shop_enabled, only: %i[ new create ]
  before_action :set_order, only: %i[ show update ]
  before_action :ensure_user_not_fraudulent, only: %i[ index show ]

  rescue_from ActiveRecord::RecordNotFound, with: :order_not_found

  # GET /orders or /orders.json
  def index
    if !current_user.admin?
      redirect_to home_path and return
    end

    @orders = current_user.orders.order(created_at: :desc)
  end

  # GET /orders/new?product_id=1
  def new
    @product = Product.find_by(id: params[:product_id])
    unless @product
      flash_warn("Product not found")
      redirect_to products_path and return
    end

    pending_db_val = if Order.respond_to?(:statuses)
      Order.statuses["pending"]
    elsif Order.const_defined?(:STATUS_VALUE_MAP)
      Order::STATUS_VALUE_MAP["pending"]
    else
      "pending"
    end

    if current_user.orders.where(product_id: @product.id, status: pending_db_val).exists?
      flash_warn("Already In Loadout")
      redirect_to products_path and return
    end

    @order = current_user.orders.build(product: @product)
    # prepopulate charm_image_url when showing the form
    @order.charm_image_url = @product.image_url if @product.image_url.present?
  end

  # GET /orders/1 or /orders/1.json
  def show
    unless (@order.user == current_user) || current_user.admin?
      flash_warn("Not authorized")
      redirect_to orders_path and return
    end

    # current behaviour: allow a status change via query param when viewing the order
    # this is mainly exercised by the cancel button on the show page
    if params[:status].present? && params[:status] == "user_denied" && @order.status == "pending"
      @order.update(status: params[:status])
      redirect_to @order and return
    end
  end

  # PUT/PATCH /orders/1
  # Used by the 'Cancel Order' button so we respect RESTful routing.
  def update
    unless @order.user == current_user || current_user.admin?
      flash_warn("Not authorized")
      redirect_to orders_path and return
    end

    if params[:status].present? && params[:status] == "user_denied" && @order.status == "pending" && @order.can_cancel?
      @order.update(status: params[:status])
    elsif params[:status].present? && params[:status] == "user_denied" && @order.status == "pending" && current_user.admin? && !@order.can_cancel? && current_user != @order.user
      @order.update(status: "cancelled")

      Comment.create!(
        user: current_user,
        commentable: @order,
        message: "Admin #{current_user.name} updated order status to '#{@order.status.humanize}'"
      )
    else
      flash_warn("Invalid status change")
      redirect_to @order and return
    end

    redirect_to @order
  end

  def admin_force_create
      @product = Product.find(params[:product_id])
      @user = User.find(params[:user_id])
      @order_status = params[:status].presence || "pending"
      @cost_to_user = params[:cost_to_user].presence

      order_attrs = {
        user: @user,
        product: @product,
        status: @order_status,
        charm_image_url: params[:charm_image_url].presence || @product.image_url
      }
      order_attrs[:admin_created] = true if Order.attribute_names.include?("admin_created")
      if @product.variable_grant? && params[:grant_amount_dollars].present?
        grant_dollars = params[:grant_amount_dollars].to_f
        order_attrs[:grant_amount_cents] = (grant_dollars * 100).round
        order_attrs[:notch_cost] = (grant_dollars / 10.0).round
        order_attrs[:cost] = (grant_dollars / 10.0).round
      end
      order_attrs[:notch_cost] = @cost_to_user.to_i if @cost_to_user.present?

      @order = Order.new(order_attrs)
      if @order.save
        flash_pass("Order force-created successfully!")
      else
        flash_warn("Failed to force-create order: #{@order.errors.full_messages.to_sentence}")
      end
      redirect_to products_path
  end

  def admin_new_order
    @products = Product.order(:name)
    @product = Product.find_by(id: params[:product_id])
    @order = current_user.orders.build(product: @product)
    @order.charm_image_url = @product.image_url if @product&.image_url.present?
  end

  # POST /orders or /orders.json
  def create
    @product = Product.find(params[:product_id])
    pending_status = order_status_value("pending")

    if pending_order_exists?(@product, pending_status)
      flash_warn("Already In Loadout")
      redirect_to products_path and return
    end

    selected_accessory_choices = normalized_accessory_group_choices
    missing_required_groups = missing_required_accessory_groups(@product, selected_accessory_choices)
    if missing_required_groups.any?
      @order = current_user.orders.build(build_order_attrs(@product, pending_status))
      missing_required_groups.each do |group|
        group_label = group.name.presence || "Accessory group"
        @order.errors.add(:base, "Please choose an option for #{group_label}.")
      end
      render :new, status: :unprocessable_entity and return
    end

    @order = current_user.orders.create!(build_order_attrs(@product, pending_status, selected_accessory_choices))
    flash_pass("Order placed successfully!")
    redirect_to products_path
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid, SQLite3::ConstraintException => e
    handle_duplicate_pending_error!(e, pending_status || order_status_value("pending"))
  rescue ActiveRecord::RecordInvalid => e
    handle_invalid_order_error!(e.record)
  end

  private
    def order_status_value(status_name)
      if Order.respond_to?(:statuses)
        Order.statuses[status_name]
      elsif Order.const_defined?(:STATUS_VALUE_MAP)
        Order::STATUS_VALUE_MAP[status_name]
      else
        status_name
      end
    end

    def pending_order_exists?(product, pending_status)
      Order.where(user_id: current_user.id, product_id: product.id, status: pending_status).exists?
    end

    def build_order_attrs(product, pending_status, selected_accessory_choices = {})
      order_attrs = { product: product, status: pending_status }
      accessory_cost_total = selected_accessory_cost_total(product, selected_accessory_choices)

      if product.variable_grant? && params[:grant_amount_dollars].present?
        grant_dollars = params[:grant_amount_dollars].to_f
        base_notch_cost = (grant_dollars / 10.0).round
        base_cost = product.credits_for_dollars(grant_dollars).to_f

        order_attrs[:grant_amount_cents] = (grant_dollars * 100).round
        order_attrs[:notch_cost] = base_notch_cost + accessory_cost_total
        order_attrs[:cost] = base_cost + accessory_cost_total
      elsif accessory_cost_total.positive?
        base_notch_cost = product.cost(current_user.set_region).to_i
        if (sale = product.active_sale)
          base_notch_cost -= sale.discount_notches.to_i
          base_notch_cost = 0 if base_notch_cost < 0
        end
        order_attrs[:notch_cost] = base_notch_cost + accessory_cost_total
        order_attrs[:cost] = product.price_currency.to_f + accessory_cost_total
      end

      charm_image_url = params[:charm_image_url].presence || product.image_url
      order_attrs[:charm_image_url] = charm_image_url if charm_image_url.present?

      accessory_extra_info_json = accessory_choices_extra_info_json(product, selected_accessory_choices)
      order_attrs[:extra_info] = accessory_extra_info_json if accessory_extra_info_json.present?

      order_attrs
    end

    def normalized_accessory_group_choices
      raw_choices = params[:accessory_group_choices]
      return {} if raw_choices.blank?

      choices_hash = if raw_choices.respond_to?(:to_unsafe_h)
        raw_choices.to_unsafe_h
      elsif raw_choices.respond_to?(:to_h)
        raw_choices.to_h
      else
        {}
      end

      choices_hash.each_with_object({}) do |(group_id, accessory_id), normalized|
        next if group_id.blank? || accessory_id.blank?

        normalized[group_id.to_s] = accessory_id.to_s
      end
    end

    def missing_required_accessory_groups(product, selected_choices)
      return [] unless product.accessory_groups.exists?

      product.accessory_groups.includes(:accessories).select do |group|
        next false unless group.required?
        next false if group.accessories.empty?

        selected_accessory_id = selected_choices[group.id.to_s]
        selected_accessory_id.blank? || group.accessories.none? { |accessory| accessory.id.to_s == selected_accessory_id }
      end
    end

    def accessory_choices_extra_info_json(product, selected_choices)
      return nil if selected_choices.blank?

      selected_map = {}

      product.accessory_groups.includes(:accessories).each do |group|
        selected_accessory_id = selected_choices[group.id.to_s]
        next if selected_accessory_id.blank?

        selected_accessory = group.accessories.find { |accessory| accessory.id.to_s == selected_accessory_id }
        next unless selected_accessory

        key = group.name.to_s.strip.downcase
        key = "group_#{group.id}" if key.blank?
        selected_map[key] = selected_accessory.name.to_s
      end

      return nil if selected_map.empty?

      JSON.generate(selected_map)
    end

    def selected_accessory_cost_total(product, selected_choices)
      return 0 if selected_choices.blank?

      total = 0
      product.accessory_groups.includes(:accessories).each do |group|
        selected_accessory_id = selected_choices[group.id.to_s]
        next if selected_accessory_id.blank?

        selected_accessory = group.accessories.find { |accessory| accessory.id.to_s == selected_accessory_id }
        total += selected_accessory.cost.to_i if selected_accessory
      end

      total
    end

    def handle_duplicate_pending_error!(error, pending_status)
      Rails.logger.warn("OrdersController#create duplicate/statement error: #{error.class} #{error.message.inspect}")
      msg = error.message.to_s
      duplicate_like = error.is_a?(ActiveRecord::RecordNotUnique) ||
                       msg.include?("UNIQUE constraint failed") ||
                       msg.match?(/duplicate/i)

      if duplicate_like && pending_order_exists?(@product, pending_status)
        flash_warn("Already In Loadout")
        redirect_to products_path and return
      end

      raise
    end

    def handle_invalid_order_error!(invalid_order)
      if insufficient_notches_error?(invalid_order)
        if denied_order_exists_for_product?(@product)
          flash_warn("Insufficient Notches — a previous denied order exists and may not have been refunded. Contact support if your balance should have been restored.")
        else
          flash_warn("Insufficient Notches")
        end
        redirect_to products_path and return
      end

      if invalid_order.product_id == @product.id
        @order = invalid_order
        render :new, status: :unprocessable_entity
      else
        flash_warn(invalid_order.errors.full_messages.to_sentence)
        redirect_to products_path and return
      end
    end

    def insufficient_notches_error?(order)
      order.errors[:base].any? { |msg| msg =~ /\AInsufficient/ }
    end

    def denied_order_exists_for_product?(product)
      denied_status = order_status_value("denied")
      current_user.orders.where(product_id: product.id, status: denied_status).exists?
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find_by_param(params[:id])
    end

    def order_not_found
      redirect_to orders_path, alert: "Order not found."
    end
end
