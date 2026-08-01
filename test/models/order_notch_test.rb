require "test_helper"

class OrderNotchTest < ActiveSupport::TestCase
  setup do
    # ensure the fixture user has some free notches to begin with
    @user = users(:one)
    @user.adjust_charm_notches!(5)

    # simple product that costs two notches
    @product = Product.create!(name: "NotchItem", notch_cost: 2)
  end

  test "order creation deducts exactly the product's notch cost" do
    assert_difference "@user.reload.free_notches", -2 do
      Order.create!(user: @user, product: @product)
    end
  end

  test "free order still creates a charm slot linked to the order" do
    free_product = Product.create!(name: "FreeItem", notch_cost: 0)

    assert_difference "@user.reload.free_notches", 0 do
      order = Order.create!(user: @user, product: free_product)
      assert_equal order, order.charm_slot.order
    end
  end

  test "rolling back an order transaction does not spend notches" do
    initial = @user.free_notches

    Order.transaction do
      Order.create!(user: @user, product: @product)
      raise ActiveRecord::Rollback
    end

    assert_equal initial, @user.reload.free_notches,
                 "callback should not run if the enclosing transaction is rolled back"
  end

  test "concurrent order attempts cannot overspend the user's notches" do
    # start with exactly two free notches so only one real purchase is allowed
    @user.adjust_charm_notches!(2)
    required = @product.notch_cost

    results = []
    threads = 2.times.map do
      Thread.new do
        begin
          results << Order.create!(user: @user, product: @product)
        rescue => e
          results << e
        end
      end
    end
    threads.each(&:join)

    @user.reload

    # after the dust settles we should never have spent more notches than
    # originally available
    assert_operator @user.free_notches, :>=, 0
    assert_operator @user.free_notches, :<=, 2

    # at most one pending order should exist for this user/product
    pending = Order.where(user: @user, product: @product, status: "pending")
    assert pending.count <= 1
  end
end
