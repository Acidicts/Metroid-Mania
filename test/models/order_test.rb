require "test_helper"

class OrderTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "statuses_for_select returns the STATUSES constant" do
    assert_equal Order::STATUSES, Order.statuses_for_select
  end

  test "string-backed status predicates work (pending?)" do
    o = Order.new(status: 'pending')
    assert_equal 'pending', o.status
    assert_predicate o, :pending?
    refute_predicate o, :shipped?
  end

  test "statuses_for_select does not call an incompatible statuses method" do
    # simulate a broken/odd-arity statuses method that would previously cause class-eval errors
    Order.define_singleton_method(:statuses) { |*_args| raise "should not be called" }

    begin
      assert_equal Order::STATUSES, Order.statuses_for_select
    ensure
      # restore environment
      Order.singleton_class.send(:remove_method, :statuses) rescue nil
    end
  end
end
