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
    # make sure baseline (created_at) is in the past; fixtures sometimes have
    # future timestamps which cause devlogged_minutes_since_baseline to ignore
    # newly created devlogs when running tests concurrently.
    p.update!(created_at: 1.hour.ago, shipped_at: nil)
    p.devlogs.destroy_all

    assert_equal 15, p.minutes_needed_for_ship_request

    p.devlogs.create!(title: "Short work", content: "x", duration_minutes: 5, log_date: Date.today, user: p.user)
    assert_equal 10, p.minutes_needed_for_ship_request

    p.devlogs.create!(title: "More work", content: "y", duration_minutes: 10, log_date: Date.today, user: p.user)
    assert_equal 0, p.minutes_needed_for_ship_request
  end

  test "total_devlogged_seconds excludes ship marker rows" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "Totals Only Devlogs", repository_url: "x", total_seconds: 8.hours.to_i)

    # Genuine user-authored devlog should always count.
    p.devlogs.create!(user: owner, title: "Actual work", content: "x", duration_seconds: 1800, log_date: Date.current)

    # Mimic legacy/corrupt marker data where a ship-marker row accidentally has user_id.
    req = p.ship_requests.create!(user: owner, requested_at: Time.current, devlogged_seconds: 1800, status: "pending")
    p.devlogs.create!(user: owner, ship_request: req, title: "Ship #1", content: "system marker", duration_seconds: 7200, log_date: Date.current)

    assert_equal 1800, p.total_devlogged_seconds
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

  test "image_url returns nil when no attachment" do
    p = Project.new
    assert_nil p.image_url
  end

  test "image_url includes port when default_url_options specify one" do
    p = Project.new
    # stub an attached blob to avoid needing real ActiveStorage setup
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "port.png", content_type: "image/png")
    p.image.attach(blob)

    # temporarily set a host/port in route defaults so project_banner_url uses it
    orig_routes = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options[:host] = "localhost"
    Rails.application.routes.default_url_options[:port] = 4000

    begin
      url = p.image_url
      assert_match %r{localhost:4000}, url, "expected blob URL to include configured port"
    ensure
      Rails.application.routes.default_url_options = orig_routes
    end
  end

  test "image_url generates blob URL for attached image" do
    p = projects(:one)
    # attach a tiny blob; using test helper to create sample PNG
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "foo.png", content_type: "image/png")
    p.image.attach(blob)

    # ensure we have a host configured so an absolute URL is generated
    orig_routes = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options[:host] = "example.com"

    begin
      url = p.image_url
      assert_match %r{https?://}, url, "expected full URL for blob"
      assert_includes url, blob.signed_id.to_s
    ensure
      Rails.application.routes.default_url_options = orig_routes
    end
  end

  test "ensure_has_image_url handles CDN failure gracefully" do
    p = projects(:one)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "bar.png", content_type: "image/png")
    p.image.attach(blob)

    [ nil, {}, { "not_url" => "x" } ].each do |fake|
      # manually stub and restore because CdnService.stub isn't available
      orig = CdnService.method(:upload_from_url)
      CdnService.define_singleton_method(:upload_from_url) { |_url| fake }
      begin
        assert_equal false, p.ensure_has_image_url,
                     "should return false when CDN upload doesn't provide a URL (got #{fake.inspect})"
        assert_nil p[:image_url]
      ensure
        CdnService.define_singleton_method(:upload_from_url, orig)
      end
    end
  end

  test "project_banner_url returns placeholder when blob not persisted" do
    p = projects(:one)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "temp.png", content_type: "image/png")
    p.image.attach(blob)

    # simulate unsaved blob state by overriding persisted?
    blob.define_singleton_method(:persisted?) { false }

    url = p.send(:project_banner_url, p)
    assert_equal "https://placehold.co/800x450", url
  end

  test "image_url writer stores attribute" do
    p = projects(:one)
    p.image_url = "http://foo"
    # DB has no column, so raw attribute access returns nil
    assert_nil p[:image_url]
    # reader should still return the cached value
    assert_equal "http://foo", p.image_url
  end
  test "ship_and_award_credits! awards credits and records them on the ship atomically" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)

    # ensure no preexisting ships or notches
    owner.charm_notches.destroy_all
    p.ships.destroy_all

    devlogged_seconds = 60 * 120 # 2 hours
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: devlogged_seconds, shipped_at: Time.current)

    expected_credits = (devlogged_seconds.to_f / 3600.0) * 0.5
    assert_in_delta expected_credits, ship.credits_awarded, 0.001
    # currency still updated for backwards compatibility
    assert_in_delta expected_credits, owner.reload.currency.to_f, 0.001
    # and owner should have expected number of notches (multiplier default 1)
    assert_equal expected_credits.to_i, owner.reload.charm_notches.count
    # ship should also expose its earned notches
    assert_equal expected_credits.to_i, ship.charm_notches.count
    assert_equal ship, owner.charm_notches.last.ship
    assert_equal ship, p.ships.order(:created_at).last
  end

  test "multipliers affect notch count and are stored" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)

    owner.charm_notches.destroy_all
    p.ships.destroy_all

    devlogged_seconds = 60 * 120 # 2 hours (ensures at least one notch before multiplier)
    multiplier = 3.0
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: devlogged_seconds, shipped_at: Time.current, multiplier: multiplier)

    expected_credits = (devlogged_seconds.to_f / 3600.0) * 0.5
    assert_in_delta expected_credits, ship.credits_awarded, 0.001
    assert_equal multiplier, ship.multiplier.to_f

    expected_notches = (expected_credits.to_i * multiplier).to_i
    assert_equal expected_notches, owner.reload.charm_notches.count
    assert_equal expected_notches, ship.charm_notches.count
    assert_equal ship, owner.charm_notches.last.ship
  end

  test "notch remainder carries over across ships" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)
    owner.charm_notches.destroy_all
    p.ships.destroy_all
    p.update_column(:notch_remainder_seconds, 0)

    # Ship 1: 1.5 hours = 5400 seconds → 0 notches (need 2h for 1 notch), 5400s remainder
    ship1 = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: 5400, shipped_at: 1.hour.ago)
    p.reload
    assert_equal 0, ship1.charm_notches.count, "1.5h is not enough for a notch"
    assert_in_delta 5400.0, p.notch_remainder_seconds, 0.01, "remainder should carry 5400s forward"

    # Ship 2: 1 hour = 3600 seconds → combined with 5400s remainder = 9000s = 2.5h → 1 notch, 1800s remainder
    ship2 = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: 3600, shipped_at: Time.current)
    p.reload
    assert_equal 1, ship2.charm_notches.count, "1h + 1.5h carry-over = 2.5h → 1 notch"
    assert_in_delta 1800.0, p.notch_remainder_seconds, 0.01, "remainder should carry 1800s (0.5h) forward"
  end

  test "notch remainder carries over with multiplier" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)
    owner.charm_notches.destroy_all
    p.ships.destroy_all
    p.update_column(:notch_remainder_seconds, 0)

    # 3 hours = 10800s → 1 raw notch (2h), 3600s remainder, with 2x multiplier → 2 notches
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: 10800, shipped_at: Time.current, multiplier: 2.0)
    p.reload
    assert_equal 2, ship.charm_notches.count, "1 raw notch × 2.0 multiplier = 2 notches"
    assert_in_delta 3600.0, p.notch_remainder_seconds, 0.01, "1h remainder carried forward"
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
    assert_in_delta 6.0, amount_zero.to_f, 0.001, "award_credits! returned unexpected amount (checks total_seconds usage)"

    # explicit nil should also use total_seconds
    amount_nil = p.award_credits!(10, seconds: nil)
    Rails.logger.debug("TEST: amount_nil=#{amount_nil.inspect} owner_currency_after_second=#{p.user.reload.currency.inspect}") if defined?(Rails)
    assert_in_delta 6.0, amount_nil.to_f, 0.001

    # after two awards the owner should have 12 total
    assert_in_delta 12.0, owner.reload.currency.to_f, 0.001

    # end-to-end via ship_and_award_credits! when devlogged_seconds is 0
    previous = owner.reload.currency.to_f
    owner.charm_notches.destroy_all
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 10, devlogged_seconds: 0, shipped_at: Time.current)
    expected = (p.total_seconds.to_f / 3600.0) * 0.5
    assert_in_delta expected, ship.credits_awarded.to_f, 0.001
    assert_in_delta previous + ship.credits_awarded.to_f, owner.reload.currency.to_f, 0.001
    # verify notches awarded on the ship
    assert_equal ship.credits_awarded.to_f.to_i, owner.reload.charm_notches.count
    assert_equal ship, owner.charm_notches.last.ship
  end
end
