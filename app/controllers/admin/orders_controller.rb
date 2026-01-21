module Admin
  class OrdersController < Admin::ApplicationController
    before_action :require_admin
    # ensure @order is set for any admin actions that operate on a single order
    before_action :set_order, only: [:show, :pend, :fulfill, :decline, :delete]

    # Gracefully handle missing orders in the admin UI so admins see a friendly message
    rescue_from ActiveRecord::RecordNotFound, with: :order_not_found

    def index
      @orders = Order.order(created_at: :desc)

      if params[:q].present?
        q = params[:q].to_s.strip
        if q.start_with?('!')
          @orders = Order.where(public_id: q)
        elsif q =~ /\A\d+\z/
          @orders = Order.where(id: q.to_i)
        else
          term = "%#{q.downcase}%"
          @orders = Order.joins(:user, :product).where("LOWER(users.email) LIKE ? OR LOWER(products.name) LIKE ? OR LOWER(orders.public_id) LIKE ?", term, term, term)
        end
      end
    end

    def show
    end

    def pend
      if @order.pending?
        redirect_back fallback_location: admin_orders_path, alert: 'Order is already pending.'
        return
      end

      previous = @order.status
      db_val = normalize_status_for_db('pending').first || (Order.respond_to?(:statuses) ? Order.statuses['pending'] : 'pending')
      @order.update!(status: db_val)
      Audit.create!(user: current_user, project: nil, action: 'order_pended', details: { order_id: @order.id, order_public_id: @order.public_id, previous_status: canonical_status(previous) })
      redirect_back fallback_location: admin_orders_path, notice: 'Order status reverted to pending.'
    end

    def fulfill
      if @order.shipped?
        redirect_back fallback_location: admin_orders_path, alert: 'Order already fulfilled.'
        return
      end

      previous = @order.status
      dbg = normalize_status_for_db('shipped')
      puts "DEBUG normalize_status_for_db('shipped') => #{dbg.inspect}"
      db_val = dbg.first || (Order.respond_to?(:statuses) ? Order.statuses['shipped'] : 'shipped')
      puts "DEBUG Admin::OrdersController#fulfill before=#{previous.inspect} db_val=#{db_val.inspect}"
      begin
        @order.update!(status: db_val)
        puts "DEBUG Admin::OrdersController#fulfill after=#{@order.reload.status.inspect}"
      rescue => e
        puts "DEBUG Admin::OrdersController#fulfill: update failed: #{e.class} - #{e.message}"
        raise
      end

      Audit.create!(user: current_user, project: nil, action: 'order_fulfilled', details: { order_id: @order.id, order_public_id: @order.public_id, previous_status: canonical_status(previous), new_status: canonical_status(@order.status) })
      redirect_back fallback_location: admin_orders_path, notice: 'Order marked as fulfilled.'
    end

    def delete
      unless @order.denied?
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
            Audit.create!(user: current_user, project: nil, action: 'order_refunded', details: { order_id: @order.id, order_public_id: @order.public_id, amount: @order.cost.to_f, previous_status: canonical_status(previous) })
          end
        end

        Audit.create!(user: current_user, project: nil, action: 'order_deleted', details: { order_id: @order.id, order_public_id: @order.public_id, previous_status: canonical_status(previous) })
        @order.destroy!
      end

      redirect_back fallback_location: admin_orders_path, notice: 'Denied order deleted.'
    end

    def decline
      if @order.denied?
        redirect_back fallback_location: admin_orders_path, alert: 'Order already declined.'
        return
      end

      # Ensure the status change, refund and audit happen in one transaction so model-level
      # after_update_commit safety-net can observe the audit and avoid double-refunds.
      previous = nil
      Order.transaction do
        previous = @order.status
        db_val = normalize_status_for_db('denied').first || (Order.respond_to?(:statuses) ? Order.statuses['denied'] : 'denied')
        @order.update!(status: db_val)

        # Refund user (only if the order had a cost)
        if @order.cost.present? && @order.cost.to_f > 0
          @order.user.update!(currency: (@order.user.currency || 0) + @order.cost.to_f)
          Audit.create!(user: current_user, project: nil, action: 'order_refunded', details: { order_id: @order.id, order_public_id: @order.public_id, amount: @order.cost.to_f, previous_status: canonical_status(previous) })
        else
          Audit.create!(user: current_user, project: nil, action: 'order_declined', details: { order_id: @order.id, order_public_id: @order.public_id, previous_status: canonical_status(previous) })
        end
      end

      redirect_back fallback_location: admin_orders_path, notice: 'Order declined and user refunded.'
    end

    private

    def set_order
      @order = Order.find_by_param(params[:id])
    end

    def order_not_found
      redirect_to admin_orders_path, alert: 'Order not found.'
    end

    # Convert stored/raw status values into a canonical string used in audits and tests.
    # Examples:
    #  - 0 (or '0') -> 'pending'
    #  - 'pending'  -> 'pending'
    #  - nil        -> nil
    def canonical_status(raw)
      return nil if raw.blank?
      # If the model offers an enum mapping, prefer that
      if Order.respond_to?(:statuses)
        if raw.is_a?(Integer) || raw.to_s =~ /\A\d+\z/
          key = Order.statuses.key(raw.to_i) rescue nil
          return key.to_s if key
        end
        return raw.to_s if Order.statuses.keys.map(&:to_s).include?(raw.to_s)
        return raw.to_s
      end

      # Last-resort fallback using STATUS_VALUE_MAP if present (handles weird numeric-string cases)
      if defined?(Order::STATUS_VALUE_MAP) && raw.to_s =~ /\A\d+\z/
        key = Order::STATUS_VALUE_MAP.invert[raw.to_i] rescue nil
        return key.to_s if key
      end

      # Fallback: if DB column is integer, try to map via statuses_for_select
      col = Order.columns_hash['status'] rescue nil
      if col && col.type == :integer
        if raw.to_s =~ /\A\d+\z/
          # numeric DB value -> canonical key when possible
          if Order.respond_to?(:statuses)
            key = Order.statuses.key(raw.to_i) rescue nil
            return [raw.to_i, key.to_s] if key
          elsif Order.const_defined?(:STATUS_VALUE_MAP)
            key = Order::STATUS_VALUE_MAP.invert[raw.to_i] rescue nil
            return [raw.to_i, key.to_s] if key
          end
          return [raw.to_i, raw.to_s]
        end

        if Order.respond_to?(:statuses_for_select)
          pair = Order.statuses_for_select.find { |_, v| v.to_s == raw.to_s }
          if pair
            # map the canonical key to the integer DB value when possible
            db_val = if Order.respond_to?(:statuses)
              Order.statuses[pair[1]]
            elsif Order.const_defined?(:STATUS_VALUE_MAP)
              Order::STATUS_VALUE_MAP[pair[1].to_s]
            else
              pair[1]
            end

            return [db_val, pair[1].to_s]
          end
        end

        return [nil, nil]
      end

      raw.to_s
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
          # numeric DB value -> try to resolve canonical key
          if Order.respond_to?(:statuses)
            key = Order.statuses.key(raw.to_i) rescue nil
            return [raw.to_i, key.to_s] if key
          elsif Order.const_defined?(:STATUS_VALUE_MAP)
            key = Order::STATUS_VALUE_MAP.invert[raw.to_i] rescue nil
            return [raw.to_i, key.to_s] if key
          end
          return [raw.to_i, raw.to_s]
        end

        if Order.respond_to?(:statuses_for_select)
          pair = Order.statuses_for_select.find { |_, v| v.to_s == raw.to_s }
          if pair
            db_val = if Order.respond_to?(:statuses)
              Order.statuses[pair[1]]
            elsif Order.const_defined?(:STATUS_VALUE_MAP)
              Order::STATUS_VALUE_MAP[pair[1].to_s]
            else
              pair[1]
            end

            return [db_val, pair[1].to_s]
          end
        end

        return [nil, nil]
      end

      # fallback to string column
      [raw.to_s, raw.to_s]
    end
  end
end
