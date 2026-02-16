require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "shipped? returns false when attribute missing (defensive_behavior)" do
    project = Project.new
    # Simulate missing column / attribute by overriding has_attribute? on the instance
    def project.has_attribute?(attr)
      false
    end

    assert_not project.shipped?
  end

  test "shipped? reflects DB value when column exists" do
    project = projects(:one)

    project.update!(shipped: true)
    assert project.shipped?, "Expected shipped? to return true after setting shipped: true"

    project.update!(shipped: false)
    assert_not project.shipped?, "Expected shipped? to return false after setting shipped: false"
  end

  test "hackatime ids must be unique across projects" do
    owner = users(:one)

    # use fresh projects (avoid fixture projects that may already be shipped)
    p1 = Project.create!(user: owner, name: "Unique1", repository_url: "x", hackatime_ids: [ "Alpha Project" ])
    p2 = Project.new(user: users(:two), name: "Unique2", repository_url: "x")

    p2.hackatime_ids = [ "Alpha Project" ]
    assert_not p2.valid?
    assert_match /already linked/, p2.errors[:hackatime_ids].join(", ")
  end

  test "cannot remove hackatime id if project was shipped using hackatime time" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "H-Used", repository_url: "x", hackatime_ids: [ "A" ], total_seconds: 3600)

    # Create a Ship that uses the project's total_seconds (no devlogs present)
    p.ship_and_award_credits!(admin_user: owner, rate: 5, devlogged_seconds: 0, shipped_at: Time.current)
    assert_predicate p.ships.last, :used_hackatime_time?

    # Attempt to remove linked hackatime id should be invalid
    p.hackatime_ids = []
    assert_not p.valid?
    assert_match /cannot remove Hackatime project\(s\).*linked when the project was shipped/, p.errors[:hackatime_ids].join(", ")
  end

  test "cannot remove hackatime id after any ship exists (even when ship used user devlogs)" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "H-NotUsed", repository_url: "x", hackatime_ids: [ "B" ], total_seconds: 3600)

    # Add user-created devlogs that fully account for the ship seconds
    d = p.devlogs.create!(title: "Work", content: "x", duration_minutes: 60, log_date: Date.today, user: owner)

    # Ship using explicit devlogged_seconds (so not relying on project's total_seconds)
    p.ship_and_award_credits!(admin_user: owner, rate: 5, devlogged_seconds: d.duration_seconds, shipped_at: Time.current)
    assert_not p.ships.last.used_hackatime_time?

    # Removing hackatime id should now be blocked because the project was shipped
    p.hackatime_ids = []
    assert_not p.valid?
    assert_match /cannot remove Hackatime project\(s\).*linked when the project was shipped/, p.errors[:hackatime_ids].join(", ")
  end

  test "can remove hackatime id when project has never been shipped" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "H-NoShip", repository_url: "x", hackatime_ids: [ "C" ], total_seconds: 3600)

    # No ships exist — removal should be allowed
    p.update!(hackatime_ids: [])
    assert_empty p.reload.hackatime_ids
  end

  test "can add a hackatime id, save it, and remove it before any ship" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "AddThenRemove", repository_url: "x", total_seconds: 3600)

    # Add and persist a Hackatime ID
    p.update!(hackatime_ids: [ "Z" ])
    assert_equal [ "Z" ], p.reload.hackatime_ids.map(&:to_s)

    # Because no ship exists after the addition, removal should be allowed
    p.update!(hackatime_ids: [])
    assert_empty p.reload.hackatime_ids
  end

  test "can add and remove hackatime id added after the last ship" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "PostShipHack", repository_url: "x", total_seconds: 3600)

    # Ship the project before any hackatime link exists
    p.ship_and_award_credits!(admin_user: owner, rate: 1, devlogged_seconds: p.total_seconds, shipped_at: Time.current)
    assert p.ships.any?

    # Add a Hackatime ID after the ship — it should NOT be considered locked
    p.update!(hackatime_ids: [ "D" ])
    assert_not p.hackatime_id_locked?("D")

    # Removing the newly added Hackatime ID should be allowed
    p.update!(hackatime_ids: [])
    assert_empty p.reload.hackatime_ids
  end

  test "minutes_needed_for_ship_request returns remaining minutes to reach 15" do
    p = projects(:one)
    p.devlogs.destroy_all

    assert_equal 15, p.minutes_needed_for_ship_request

    p.devlogs.create!(title: "Short work", content: "x", duration_minutes: 5, log_date: Date.today, user: p.user)
    assert_equal 10, p.minutes_needed_for_ship_request

    p.devlogs.create!(title: "More work", content: "y", duration_minutes: 10, log_date: Date.today, user: p.user)
    assert_equal 0, p.minutes_needed_for_ship_request
  end

  test "github_readme_present? returns true when explicit readme_url present" do
    p = Project.new(user: users(:one), name: "R", repository_url: "https://github.com/owner/repo", readme_url: "https://example.com/README.md")
    assert_predicate p, :github_readme_present?
  end

  test "github_readme_present? checks raw.githubusercontent and returns true on HEAD success" do
    p = Project.new(user: users(:one), name: "GH-Readme", repository_url: "https://github.com/owner/repo")

    # fake Net::HTTP that returns HTTPOK on HEAD
    fake_response = Net::HTTPOK.new("1.1", "200", "OK")
    mock_http = Object.new
    mock_http.define_singleton_method(:request) do |_req|
      fake_response
    end

    orig = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) do |*args, &blk|
      blk.call(mock_http)
    end

    begin
      assert_equal true, p.github_readme_present?
    ensure
      Net::HTTP.define_singleton_method(:start) { |*a, &b| orig.call(*a, &b) }
    end
  end

  test "github_repo_public? returns true when GitHub repo page returns 200" do
    p = Project.new(user: users(:one), name: "GH-Pub", repository_url: "https://github.com/owner/repo")

    fake_response = Net::HTTPOK.new("1.1", "200", "OK")
    mock_http = Object.new
    mock_http.define_singleton_method(:request) { |_req| fake_response }

    orig = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) do |*args, &blk|
      blk.call(mock_http)
    end

    begin
      assert_predicate p, :github_repo_public?
    ensure
      Net::HTTP.define_singleton_method(:start) { |*a, &b| orig.call(*a, &b) }
    end
  end

  test "clonable? returns true for common git URL formats and HTTP(S) URLs" do
    p1 = Project.new(user: users(:one), name: "A", repository_url: "git@example.com:owner/repo.git")
    p2 = Project.new(user: users(:one), name: "B", repository_url: "https://example.com/repo.git")
    p3 = Project.new(user: users(:one), name: "C", repository_url: "https://example.com/some/path")

    assert_predicate p1, :clonable?
    assert_predicate p2, :clonable?
    assert_predicate p3, :clonable?
  end

  test "ship_checklist shows correct checks for README, repo, clonable and banner image" do
    p = projects(:one)

    # stub predicates on the instance
    def p.github_repo_public?; true; end
    def p.github_readme_present?; true; end
    def p.clonable?; true; end
    def p.image; Struct.new(:attached?).new(true); end

    md = Class.new { include ShipRequestsHelper }.new.ship_checklist(p)
    assert_match /Github Repo is Public/, md
    assert_match /Project has a README/, md
    assert_match /Project is clonable/, md
    assert_match /Project has a banner image/, md
    assert_match /\[x\]/, md
  end
  test "ship_and_award_credits! awards credits and records them on the ship atomically" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)

    # ensure no preexisting ships
    p.ships.destroy_all

    devlogged_seconds = 60 * 120 # 2 hours
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: devlogged_seconds, shipped_at: Time.current)

    assert_in_delta 10.0, ship.credits_awarded, 0.001
    assert_in_delta 10.0, owner.reload.currency.to_f, 0.001
    assert_equal ship, p.ships.order(:created_at).last
  end

  test "award_credits! falls back to total_seconds when seconds argument is 0 or nil" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)

    # project has 12 hours recorded
    p.update!(total_seconds: 12.hours.to_i)
    assert_equal 12.hours.to_i, p.total_seconds, "fixture/update sanity: total_seconds should be 12h"

    # explicit zero should fall back to total_seconds
    amount_zero = p.award_credits!(10, seconds: 0)
    Rails.logger.debug("TEST: amount_zero=#{amount_zero.inspect} owner_currency_after_first=#{p.user.reload.currency.inspect}") if defined?(Rails)
    assert_in_delta 120.0, amount_zero.to_f, 0.001, "award_credits! returned unexpected amount (checks total_seconds usage)"

    # explicit nil should also use total_seconds
    amount_nil = p.award_credits!(10, seconds: nil)
    Rails.logger.debug("TEST: amount_nil=#{amount_nil.inspect} owner_currency_after_second=#{p.user.reload.currency.inspect}") if defined?(Rails)
    assert_in_delta 120.0, amount_nil.to_f, 0.001

    # after two awards the owner should have 240 total
    assert_in_delta 240.0, owner.reload.currency.to_f, 0.001

    # end-to-end via ship_and_award_credits! when devlogged_seconds is 0
    previous = owner.reload.currency.to_f
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 10, devlogged_seconds: 0, shipped_at: Time.current)
    assert_in_delta 120.0, ship.credits_awarded.to_f, 0.001
    assert_in_delta previous + ship.credits_awarded.to_f, owner.reload.currency.to_f, 0.001
  end
end
