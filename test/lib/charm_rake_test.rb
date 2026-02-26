require "test_helper"
require "rake"

class CharmRakeTest < ActiveSupport::TestCase
  setup do
    # load rake tasks once
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  test "reconcile task processes users and creates notches" do
    # choose an owner distinct from the shipper so we can manually create ships
    owner = users(:two)
    shipper = users(:one)
    project = projects(:one)

    # make sure the project is owned by our test owner
    project.update!(user: owner)

    # clear any existing notches for the owner; this ensures our test starts
    # with a clean slate.  We avoid calling helper methods that could re-add
    # notches via callbacks.
    CharmNotch.where(user_id: owner.id).delete_all
    owner.reload

    assert_equal 0, owner.charm_notches.count, "fixture cleanup failed"

    # create a ship record for the project; no notches should be added yet
    # use explicit Ship.create! to avoid any association surprises
    Ship.create!(project: project, user: shipper, shipped_at: Time.current,
                 devlogged_seconds: 4.hours.to_i, credits_awarded: 0)

    owner.reload
    assert_equal 0, owner.charm_notches.count, "no notches should exist before reconciliation"

    # run the rake task for our owner only
    Rake::Task["charm:reconcile"].invoke(owner.id)

    owner.reload
    # 4 hours at 0.5 notches per hour should yield two notches
    expected = ((4.hours.to_i / 3600.0) * 0.5).floor
    assert_equal expected, owner.charm_notches.count
  ensure
    Rake::Task["charm:reconcile"].reenable
  end
end
