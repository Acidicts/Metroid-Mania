module Admin
  class OrdersController < ApplicationController
    before_action :require_admin
    # ensure @order is set for any admin actions that operate on a single order
    before_action :set_order, only: [:show, :pend, :fulfill, :decline, :delete]

    # Gracefully handle missing orders in the admin UI so admins see a friendly message
    rescue_from ActiveRecord::RecordNotFound, with: :order_not_found

    def index
      @orders = Order.order(created_at: :desc)
    end

    def show
    end

    def pend
      if @order.pending?
        redirect_back fallback_location: admin_orders_path, alert: 'Order is already pending.'
        return
      end

      previous = @order.status
      @order.update!(status: '0')
      Audit.create!(user: current_user, project: nil, action: 'order_pended', details: { order_id: @order.id, previous_status: previous })
      redirect_back fallback_location: admin_orders_path, notice: 'Order status reverted to pending.'
    end

    def fulfill
      if @order.status == "2"
        redirect_back fallback_location: admin_orders_path, alert: 'Order already fulfilled.'
        return
      end

      previous = @order.status
      @order.update!(status: '2')
      Audit.create!(user: current_user, project: nil, action: 'order_fulfilled', details: { order_id: @order.id, previous_status: previous, new_status: @order.status })
      redirect_back fallback_location: admin_orders_path, notice: 'Order marked as fulfilled.'
    end

    def delete
      if !(@order.status == "1")
        redirect_back fallback_location: admin_orders_path, alert: 'Only denied orders can be deleted.'
        return
      end

      previous = @order.status

      Order.transaction do
        # If the order is denied but a refund audit doesn't exist, refund the user now (idempotent)
        if @order.cost.present? && @order.cost.to_f > 0
          adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
          refund_exists = if adapter.include?("sqlite")
            Audit.where("action = ? AND json_extract(details, '$.order_id') = ?", 'order_refunded', @order.id.to_s).exists?
          else
            Audit.where("action = ? AND (details ->> 'order_id')::text = ?", 'order_refunded', @order.id.to_s).exists?
          end

          unless refund_exists
            @order.user.update!(currency: (@order.user.currency || 0) + @order.cost.to_f)
            Audit.create!(user: current_user, project: nil, action: 'order_refunded', details: { order_id: @order.id, amount: @order.cost.to_f, previous_status: previous })
          end
        end

        Audit.create!(user: current_user, project: nil, action: 'order_deleted', details: { order_id: @order.id, previous_status: previous })
        @order.destroy!
      end

      redirect_back fallback_location: admin_orders_path, notice: 'Denied order deleted.'
    end

    def decline
      if @order.status == "1"
        redirect_back fallback_location: admin_orders_path, alert: 'Order already declined.'
        return
      end

      # Ensure the status change, refund and audit happen in one transaction so model-level
      # after_update_commit safety-net can observe the audit and avoid double-refunds.
      previous = nil
      Order.transaction do
        previous = @order.status
        @order.update!(status: '1')

        # Refund user (only if the order had a cost)
        if @order.cost.present? && @order.cost.to_f > 0
          @order.user.update!(currency: (@order.user.currency || 0) + @order.cost.to_f)
          Audit.create!(user: current_user, project: nil, action: 'order_refunded', details: { order_id: @order.id, amount: @order.cost.to_f, previous_status: previous })
        else
          Audit.create!(user: current_user, project: nil, action: 'order_declined', details: { order_id: @order.id, previous_status: previous })
        end
      end

      redirect_back fallback_location: admin_orders_path, notice: 'Order declined and user refunded.'
    end

    private

    def set_order
      @order = Order.find(params[:id])
    end

    def order_not_found
      redirect_to admin_orders_path, alert: 'Order not found.'
    end

    # Normalize an incoming status (string or numeric) into:
    #  - db_value: value suitable for ActiveRecord queries/updates
    #  - canonical: canonical string key for comparison / user-facing checks
    # Returns [db_value, canonical] or [nil, nil] if invalid.
    def normalize_status_for_db(raw)
      return [nil, nil] if raw.blank?

      if Order.respond_to?(:statuses)
        # model uses enum; accept either key or numeric index
        if raw =~ /\A\d+\z/
          key = Order.statuses.key(raw.to_i)
          return [key, key] if key
          return [nil, nil]
        end
        return [raw.to_s, raw.to_s] if Order.statuses.keys.map(&:to_s).include?(raw.to_s)
        return [nil, nil]
      end

      # non-enum: detect column type and convert appropriately
      col = Order.columns_hash['status'] rescue nil
      if col && col.type == :integer
        if raw =~ /\A\d+\z/
          return [raw.to_i, raw.to_i]
        end
        if Order.respond_to?(:statuses_for_select)
          pair = Order.statuses_for_select.find { |_, v| v.to_s == raw.to_s || v.to_s == raw.to_s }
          return [pair[1].to_i, pair[1].to_i] if pair
        end
        return [nil, nil]
      end

      # fallback to string column
      [raw.to_s, raw.to_s]
    end
  end
end
