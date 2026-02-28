require "test_helper"

class WishlistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # use an admin user for all wishlist controller tests so that the
    # `require_admin` and ownership filters don't prevent basic CRUD.
    @user = users(:one)
    @user.update!(role: :admin)

    # create a wishlist explicitly rather than relying on fixtures.  The
    # User model now auto-creates a wishlist on creation, but constructing one
    # manually keeps the test deterministic and avoids duplicate records.
    @wishlist = @user.wishlist || Wishlist.create!(user: @user)

    # sign in for actions
    sign_in_as(@user)
  end

  test "should get index" do
    get wishlists_url
    assert_response :success
  end

  test "should get new" do
    get new_wishlist_url
    assert_response :success
  end

  test "should create wishlist" do
    assert_difference("Wishlist.count") do
      post wishlists_url, params: { wishlist: { user_id: @wishlist.user_id } }
    end

    assert_redirected_to wishlist_url(Wishlist.last)
  end

  test "should show wishlist" do
    get wishlist_url(@wishlist)
    assert_response :success
  end

  test "should get edit" do
    get edit_wishlist_url(@wishlist)
    assert_response :success
  end

  test "should update wishlist" do
    patch wishlist_url(@wishlist), params: { wishlist: { user_id: @wishlist.user_id } }
    assert_redirected_to wishlist_url(@wishlist)
  end

  test "should destroy wishlist" do
    assert_difference("Wishlist.count", -1) do
      delete wishlist_url(@wishlist)
    end

    assert_redirected_to wishlists_url
  end

  test "can add and remove products via member routes" do
    user = users(:one)
    # make sure a wishlist exists for the fixture user
    wl = user.wishlist || Wishlist.create!(user: user)
    product = products(:one)

    # sign in to satisfy authentication requirement
    sign_in_as(user)

    # ordinary HTML (non‑Turbo) requests should redirect back so the caller
    # sees the updated wishlist.  Setting a referer header imitates the
    # browser behaviour on the product index page.
    post add_product_wishlist_path(wl), params: { product_id: product.id },
         headers: { "HTTP_REFERER" => products_url }
    assert_redirected_to products_url
    assert_includes wl.reload.product_ids.map(&:to_i), product.id

    # turbo stream request should return a replacement partial
    post add_product_wishlist_path(wl), params: { product_id: products(:two).id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_match(/turbo-stream/, response.media_type)
    assert_match(/replace.*#{dom_id(wl)}/, response.body)
    assert_match products(:two).name, response.body

    # removal in the HTML case also redirects and updates the record
    post remove_product_wishlist_path(wl), params: { product_id: products(:two).id },
         headers: { "HTTP_REFERER" => products_url }
    assert_redirected_to products_url
    refute_includes wl.reload.product_ids.map(&:to_i), products(:two).id

    post remove_product_wishlist_path(wl), params: { product_id: product.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_match(/turbo-stream/, response.media_type)
    assert_match(/replace.*#{dom_id(wl)}/, response.body)
  end
end
