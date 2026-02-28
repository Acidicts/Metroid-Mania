require "test_helper"

class CharmSlotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @charm_slot = charm_slots(:one)
    # ensure asset check passes during view rendering in tests
    ApplicationController.helpers.singleton_class.class_eval do
      define_method(:asset_exists?) { |*| true }
    end
  end

  test "should get index" do
    get charm_slots_url
    assert_response :success
  end

  test "non-admin index returns user's slots" do
    user = users(:one)
    sign_in_as(user)
    get charm_slots_url
    assert_response :success
  end

  test "submit loadout transitions pending slots" do
    user = users(:one)
    sign_in_as(user)
    # create two fresh pending orders for this user with zero notch cost to avoid validation
    prod1 = Product.create!(name: "Temp1", steam_app_id: 101, price_currency: 0.0, notch_cost: 0)
    prod2 = Product.create!(name: "Temp2", steam_app_id: 102, price_currency: 0.0, notch_cost: 0)
    pending_order1 = Order.create!(user: user, product: prod1, status: "pending", cost: 0)
    pending_order2 = Order.create!(user: user, product: prod2, status: "pending", cost: 0)

    user.charm_slots.create!(order: pending_order1)
    user.charm_slots.create!(order: pending_order2)

    post submit_charm_slots_url
    assert_redirected_to charm_slots_url
    assert_equal "Loadout submitted successfully.", flash[:notice]

    # both orders should now be submitted
    assert_equal "submitted", pending_order1.reload.status
    assert_equal "submitted", pending_order2.reload.status
  end

  test "admin can submit another user's loadout" do
    admin = users(:one)
    admin.update!(role: :admin)
    other = users(:two)
    sign_in_as(admin)
    other_prod = Product.create!(name: "TempO", steam_app_id: 103, price_currency: 0.0, notch_cost: 0)
    other_order = Order.create!(user: other, product: other_prod, status: "pending", cost: 0)
    other.charm_slots.create!(order: other_order)

    post submit_charm_slots_url(user_id: other.id)
    assert_redirected_to charm_slots_url
    assert_equal "submitted", other_order.reload.status
  end

  test "loadout only filters pending slots in DB" do
    user = users(:one)
    sign_in_as(user)
    CharmSlot.where(user: user).destroy_all
    user.update_column(:charm_slots, 2)

    # create a mix of pending and non-pending records
    prod = Product.create!(name: "Tmp", steam_app_id: 999, price_currency: 0.0, notch_cost: 0)
    pending_order = Order.create!(user: user, product: prod, status: "pending", cost: 0)
    submitted_order = Order.create!(user: user, product: prod, status: "submitted", cost: 0)
    user.charm_slots.create!(order: pending_order)
    user.charm_slots.create!(order: submitted_order)

    # DB should contain both slots, but the query used by the header should
    # only return the pending one.
    db_slots = user.charm_slots.joins(:order).merge(Order.pending)
    assert_equal 1, db_slots.count
  end

  test "header loadout partial renders only pending slots on arbitrary page" do
    user = users(:one)
    sign_in_as(user)
    CharmSlot.where(user: user).destroy_all
    user.update_column(:charm_slots, 2)

    prod = Product.create!(name: "Tmp2", steam_app_id: 1000, price_currency: 0.0, notch_cost: 0)
    pending_order = Order.create!(user: user, product: prod, status: "pending", cost: 0)
    submitted_order = Order.create!(user: user, product: prod, status: "submitted", cost: 0)
    user.charm_slots.create!(order: pending_order)
    user.charm_slots.create!(order: submitted_order)

    # pick a page where the loadout partial is displayed (root path works)
    get root_url
    assert_response :success
    assert_select "#charm_slots" do
      assert_select "div[id^=charm_slot_]", count: 1
    end
  end

  test "should get new" do
    get new_charm_slot_url
    assert_response :success
  end

  test "should create charm_slot" do
    sign_in_as(@charm_slot.user)
    assert_difference("CharmSlot.count", 1) do
      post charm_slots_url, params: { charm_slot: { user_id: @charm_slot.user_id } }
    end

    assert_redirected_to charm_slot_url(CharmSlot.last)
  end

  test "can create charm_slot without an order" do
    assert_difference("CharmSlot.count") do
      post charm_slots_url, params: { charm_slot: { user_id: @charm_slot.user_id } }
    end

    created = CharmSlot.last
    assert_nil created.order
    assert_redirected_to charm_slot_url(created)
  end

  test "should show charm_slot" do
    get charm_slot_url(@charm_slot)
    assert_response :success
  end

  test "should get edit" do
    get edit_charm_slot_url(@charm_slot)
    assert_response :success
  end

  test "should update charm_slot" do
    patch charm_slot_url(@charm_slot), params: { charm_slot: { order_id: @charm_slot.order_id, user_id: @charm_slot.user_id } }
    assert_redirected_to charm_slot_url(@charm_slot)
  end

  test "should destroy charm_slot" do
    sign_in_as(@charm_slot.user)
    assert_difference("CharmSlot.count", -1) do
      delete charm_slot_url(@charm_slot)
    end

    assert_redirected_to charm_slots_url
  end

  test "owner can remove charm from slot" do
    # user must be signed in, otherwise authorization will block
    sign_in_as(@charm_slot.user)

    # assign an order and a notch to ensure removal does something
    order = orders(:one)
    @charm_slot.update!(order: order)
    notch = charm_notches(:one)
    notch.update!(charm_slot: @charm_slot)

    patch remove_charm_slot_url(@charm_slot)
    assert_redirected_to charm_slots_url

    @charm_slot.reload
    assert_nil @charm_slot.order_id
    assert_equal 0, @charm_slot.charm_notches.count
  end

  test "unauthorized user cannot remove" do
    # sign in as a different user
    other = users(:two)
    sign_in_as(other)

    patch remove_charm_slot_url(@charm_slot)
    assert_redirected_to charm_slots_url
    assert_equal flash[:warning], "You are not Authorised to do this"
  end
end
