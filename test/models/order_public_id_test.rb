require "test_helper"

class OrderPublicIdTest < ActiveSupport::TestCase
  test "public_id is generated on create and has expected format" do
    p = Product.create!(name: 'TempTestProd', steam_app_id: 9000, price_currency: 1.0)
    u = users(:one)
    u.update!(currency: 100.0)

    o = Order.create!(user: u, product: p)
    assert o.public_id.present?, "public_id should be generated"
    assert_match /\A![A-Za-z0-9]{6}\z/, o.public_id, "public_id should match !xxxxxx pattern"
    assert_equal o.public_id, o.to_param
  end

  test "public_id is unique" do
    u = users(:one)
    u.update!(currency: 100.0)
    p1 = Product.create!(name: 'TempA', steam_app_id: 9001, price_currency: 1.0)
    p2 = Product.create!(name: 'TempB', steam_app_id: 9002, price_currency: 2.0)

    o1 = Order.create!(user: u, product: p1)
    o2 = Order.create!(user: u, product: p2)

    assert_not_equal o1.public_id, o2.public_id
  end
end
