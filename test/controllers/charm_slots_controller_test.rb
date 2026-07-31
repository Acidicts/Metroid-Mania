require "test_helper"

class CharmSlotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get index for regular user" do
    get charm_slots_url
    assert_response :success
  end

  test "admin can see all slots" do
    sign_in_as(users(:admin))
    get charm_slots_url
    assert_response :success
  end

  test "should get new" do
    get new_charm_slot_url
    assert_response :success
  end

  test "should create charm slot" do
    assert_difference("CharmSlot.count") do
      post charm_slots_url, params: { charm_slot: { user_id: users(:one).id } }
    end
    assert_response :redirect
  end

  test "create with invalid params renders new" do
    post charm_slots_url, params: { charm_slot: { user_id: nil } }
    assert_response :unprocessable_entity
  end

  test "should show charm slot" do
    slot = CharmSlot.create!(user: users(:one))
    get charm_slot_url(slot)
    assert_response :success
  end

  test "should get edit" do
    slot = CharmSlot.create!(user: users(:one))
    get edit_charm_slot_url(slot)
    assert_response :success
  end

  test "should update charm slot" do
    slot = CharmSlot.create!(user: users(:one))
    patch charm_slot_url(slot), params: { charm_slot: { user_id: users(:one).id } }
    assert_response :redirect
  end

  test "should destroy charm slot" do
    slot = CharmSlot.create!(user: users(:one))
    assert_difference("CharmSlot.count", -1) do
      delete charm_slot_url(slot)
    end
    assert_response :redirect
  end

  test "submit transitions pending orders to submitted" do
    user = users(:one)
    user.adjust_charm_notches!(10)
    product = Product.create!(name: "TestSubmit", notch_cost: 1, stock: 10, limited: false)
    slot = CharmSlot.create!(user: user)
    order = Order.new(user: user, product: product, notch_cost: 1)
    order.set_public_id
    order.save!(validate: false)
    slot.update_column(:order_id, order.id)

    post submit_charm_slots_url
    assert_response :redirect
    assert_equal "submitted", order.reload.status
  end

  test "admin can submit for specific user" do
    sign_in_as(users(:admin))
    user = users(:one)
    user.adjust_charm_notches!(10)
    product = Product.create!(name: "TestAdminSubmit", notch_cost: 1, stock: 10, limited: false)
    slot = CharmSlot.create!(user: user)
    order = Order.new(user: user, product: product, notch_cost: 1)
    order.set_public_id
    order.save!(validate: false)
    slot.update_column(:order_id, order.id)

    post submit_charm_slots_url(user_id: user.id)
    assert_response :redirect
    assert_equal "submitted", order.reload.status
  end

  test "non-owner cannot destroy other user's slot" do
    other = users(:two)
    slot = CharmSlot.create!(user: other)
    sign_in_as(users(:one))
    delete charm_slot_url(slot)
    assert_response :redirect
    assert CharmSlot.exists?(slot.id)
  end

  test "charm slots index renders without login" do
    get charm_slots_url
    assert_response :success
  end
end
