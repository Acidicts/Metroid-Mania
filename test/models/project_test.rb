require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "shipped? returns false when attribute missing (defensive_behavior)" do
    project = Project.new
    def project.has_attribute?(attr)
      false
    end

    assert_not project.shipped?
  end

  test "shipped? reflects DB value when column exists" do
    project = projects(:one)

    project.update!(shipped: true)
    assert project.shipped?

    project.update!(shipped: false)
    assert_not project.shipped?
  end

  test "hackatime ids must be unique across projects" do
    owner = users(:one)
    p1 = Project.create!(user: owner, name: "Unique1", repository_url: "x", hackatime_ids: [ "Alpha Project" ])
    p2 = Project.new(user: users(:two), name: "Unique2", repository_url: "x")

    p2.hackatime_ids = [ "Alpha Project" ]
    assert_not p2.valid?
    assert_match /already linked/, p2.errors[:hackatime_ids].join(", ")
  end

  test "cannot remove hackatime id if project was shipped using hackatime time" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "H-Used", repository_url: "x", hackatime_ids: [ "A" ], total_seconds: 3600)

    p.ship_and_award_credits!(admin_user: owner, rate: 5, devlogged_seconds: 0, shipped_at: Time.current)
    assert_predicate p.ships.last, :used_hackatime_time?

    p.hackatime_ids = []
    assert_not p.valid?
    assert_match /cannot remove Hackatime project\(s\).*linked when the project was shipped/, p.errors[:hackatime_ids].join(", ")
  end

  test "cannot remove hackatime id after any ship exists (even when ship used user devlogs)" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "H-NotUsed", repository_url: "x", hackatime_ids: [ "B" ], total_seconds: 3600)

    d = p.devlogs.create!(title: "Work", content: "x", duration_minutes: 60, log_date: Date.today, user: owner)
    p.ship_and_award_credits!(admin_user: owner, rate: 5, devlogged_seconds: d.duration_seconds, shipped_at: Time.current)
    assert_not p.ships.last.used_hackatime_time?

    p.hackatime_ids = []
    assert_not p.valid?
    assert_match /cannot remove Hackatime project\(s\).*linked when the project was shipped/, p.errors[:hackatime_ids].join(", ")
  end

  test "can remove hackatime id when project has never been shipped" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "H-NoShip", repository_url: "x", hackatime_ids: [ "C" ], total_seconds: 3600)

    p.update!(hackatime_ids: [])
    assert_empty p.reload.hackatime_ids
  end

  test "can add a hackatime id, save it, and remove it before any ship" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "AddThenRemove", repository_url: "x", total_seconds: 3600)

    p.update!(hackatime_ids: [ "Z" ])
    assert_equal [ "Z" ], p.reload.hackatime_ids.map(&:to_s)

    p.update!(hackatime_ids: [])
    assert_empty p.reload.hackatime_ids
  end

  test "can add and remove hackatime id added after the last ship" do
    owner = users(:one)
    p = Project.create!(user: owner, name: "PostShipHack", repository_url: "x", total_seconds: 3600)

    p.ship_and_award_credits!(admin_user: owner, rate: 1, devlogged_seconds: p.total_seconds, shipped_at: Time.current)
    assert p.ships.any?

    p.update!(hackatime_ids: [ "D" ])
    assert_not p.hackatime_id_locked?("D")

    p.update!(hackatime_ids: [])
    assert_empty p.reload.hackatime_ids
  end

  test "minutes_needed_for_ship_request returns remaining minutes to reach 15" do
    p = projects(:one)
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

    p.devlogs.create!(user: owner, title: "Actual work", content: "x", duration_seconds: 1800, log_date: Date.current)

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
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "port.png", content_type: "image/png")
    p.image.attach(blob)

    orig_routes = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options[:host] = "localhost"
    Rails.application.routes.default_url_options[:port] = 4000

    begin
      url = p.image_url
      assert_match %r{localhost:4000}, url
    ensure
      Rails.application.routes.default_url_options = orig_routes
    end
  end

  test "image_url generates blob URL for attached image" do
    p = projects(:one)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "foo.png", content_type: "image/png")
    p.image.attach(blob)

    orig_routes = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options[:host] = "example.com"

    begin
      url = p.image_url
      assert_match %r{https?://}, url
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
      orig = CdnService.method(:upload_from_url)
      CdnService.define_singleton_method(:upload_from_url) { |_url| fake }
      begin
        assert_equal false, p.ensure_has_image_url
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

    blob.define_singleton_method(:persisted?) { false }

    url = p.send(:project_banner_url, p)
    assert_equal "https://placehold.co/800x450", url
  end

  test "image_url writer stores attribute" do
    p = projects(:one)
    p.image_url = "http://foo"
    assert_nil p[:image_url]
    assert_equal "http://foo", p.image_url
  end

  test "ship_and_award_credits! awards credits and records them on the ship atomically" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)

    owner.charm_notches.destroy_all
    p.ships.destroy_all

    devlogged_seconds = 60 * 120
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: devlogged_seconds, shipped_at: Time.current)

    expected_credits = (devlogged_seconds.to_f / 3600.0) * 0.5
    assert_in_delta expected_credits, ship.credits_awarded, 0.001
    assert_in_delta expected_credits, owner.reload.currency.to_f, 0.001
    assert_equal expected_credits.to_i, owner.reload.charm_notches.count
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

    devlogged_seconds = 60 * 120
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

    ship1 = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: 5400, shipped_at: 1.hour.ago)
    p.reload
    assert_equal 0, ship1.charm_notches.count
    assert_in_delta 5400.0, p.notch_remainder_seconds, 0.01

    ship2 = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: 3600, shipped_at: Time.current)
    p.reload
    assert_equal 1, ship2.charm_notches.count
    assert_in_delta 1800.0, p.notch_remainder_seconds, 0.01
  end

  test "notch remainder carries over with multiplier" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)
    owner.charm_notches.destroy_all
    p.ships.destroy_all
    p.update_column(:notch_remainder_seconds, 0)

    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: 10800, shipped_at: Time.current, multiplier: 2.0)
    p.reload
    assert_equal 2, ship.charm_notches.count
    assert_in_delta 3600.0, p.notch_remainder_seconds, 0.01
  end

  test "award_credits! falls back to total_seconds when seconds argument is 0 or nil" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user

    p.update!(total_seconds: 12.hours.to_i)

    amount_zero = p.award_credits!(10, seconds: 0)
    assert_in_delta 6.0, amount_zero.to_f, 0.001

    amount_nil = p.award_credits!(10, seconds: nil)
    assert_in_delta 6.0, amount_nil.to_f, 0.001

    owner.charm_notches.destroy_all
    ship = p.ship_and_award_credits!(admin_user: admin, rate: 10, devlogged_seconds: 0, shipped_at: Time.current)
    expected = (p.total_seconds.to_f / 3600.0) * 0.5
    assert_in_delta expected, ship.credits_awarded.to_f, 0.001
    assert_in_delta ship.credits_awarded.to_f, owner.reload.currency.to_f, 0.001
    assert_equal ship.credits_awarded.to_f.to_i, owner.reload.charm_notches.count
    assert_equal ship, owner.charm_notches.last.ship
  end

  # --- regulated_repository_url ---

  test "regulated_repository_url returns https unchanged" do
    p = Project.new(repository_url: "https://github.com/owner/repo")
    assert_equal "https://github.com/owner/repo", p.regulated_repository_url
  end

  test "regulated_repository_url converts http to https" do
    p = Project.new(repository_url: "http://github.com/owner/repo")
    assert_equal "https://github.com/owner/repo", p.regulated_repository_url
  end

  test "regulated_repository_url prepends https to bare github.com" do
    p = Project.new(repository_url: "github.com/owner/repo")
    assert_equal "https://github.com/owner/repo", p.regulated_repository_url
  end

  test "regulated_repository_url handles user/repo pattern" do
    p = Project.new(repository_url: "owner/repo")
    assert_equal "https://github.com/owner/repo", p.regulated_repository_url
  end

  test "regulated_repository_url returns fallback for unrecognized format" do
    p = Project.new(repository_url: "random-string")
    assert_equal "random-string", p.regulated_repository_url
  end

  # --- tags ---

  test "tags returns array with project tag name" do
    tag = ProjectTag.create!(tag: "gamedev")
    p = projects(:one)
    p.update!(project_tag: tag)
    assert_equal [ "gamedev" ], p.tags
  end

  test "tags returns empty array when no tag" do
    p = projects(:one)
    p.update!(project_tag: nil)
    assert_equal [], p.tags
  end

  test "tags= assigns existing tag" do
    tag = ProjectTag.create!(tag: "existing")
    p = projects(:one)
    p.tags = [ "existing" ]
    assert_equal tag.id, p.project_tag_id
  end

  test "tags= creates new tag when not found" do
    p = projects(:one)
    p.tags = [ "brand-new" ]
    assert p.project_tag.present?
    assert_equal "brand-new", p.project_tag.tag
  end

  test "tags= clears tag when empty" do
    tag = ProjectTag.create!(tag: "to-clear")
    p = projects(:one)
    p.update!(project_tag: tag)
    p.tags = []
    assert_nil p.project_tag
  end

  # --- hackatime_ids accessor ---

  test "hackatime_ids returns empty array for nil column" do
    p = Project.new
    p.write_attribute(:hackatime_ids, nil)
    assert_equal [], p.hackatime_ids
  end

  test "hackatime_ids returns empty array for empty string" do
    p = Project.new
    p.write_attribute(:hackatime_ids, "")
    assert_equal [], p.hackatime_ids
  end

  test "hackatime_ids parses YAML array" do
    p = Project.new
    p.write_attribute(:hackatime_ids, [ "Project A", "Project B" ].to_yaml)
    assert_equal [ "Project A", "Project B" ], p.hackatime_ids
  end

  test "hackatime_ids returns empty array for blank string" do
    p = Project.new
    p.write_attribute(:hackatime_ids, "")
    assert_equal [], p.hackatime_ids
  end

  test "hackatime_ids= stores YAML" do
    p = Project.new
    p.hackatime_ids = [ "X", "Y" ]
    raw = p.read_attribute(:hackatime_ids)
    assert_equal [ "X", "Y" ], YAML.safe_load(raw)
  end

  test "hackatime_ids= stores nil for blank values" do
    p = Project.new
    p.hackatime_ids = []
    assert_nil p.read_attribute(:hackatime_ids)
  end

  # --- charm_notches_count ---

  test "charm_notches_count sums notches across ships" do
    p = projects(:one)
    owner = p.user
    p.ships.destroy_all
    ship1 = p.ships.create!(user: owner, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: Time.current)
    ship2 = p.ships.create!(user: owner, devlogged_seconds: 7200, credits_awarded: 2.0, shipped_at: Time.current)
    3.times { CharmNotch.create!(user: owner, ship: ship1) }
    2.times { CharmNotch.create!(user: owner, ship: ship2) }

    assert_equal 5, p.charm_notches_count
  end

  # --- computed_status / recalculate_status! ---

  test "computed_status returns shipped when project has ships" do
    p = projects(:one)
    p.ships.create!(user: p.user, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: Time.current)
    assert_equal "shipped", p.computed_status
  end

  test "computed_status returns shipped when shipped flag is true" do
    p = projects(:one)
    p.update!(shipped: true)
    assert_equal "shipped", p.computed_status
  end

  test "computed_status returns unshipped when no ships and no request" do
    p = projects(:one)
    p.ships.destroy_all
    p.ship_requests.destroy_all
    assert_equal "unshipped", p.computed_status
  end

  test "recalculate_status! updates status based on ships" do
    p = projects(:one)
    p.ships.destroy_all
    p.update!(status: "pending")
    p.ships.create!(user: p.user, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: Time.current)
    p.recalculate_status!
    assert_equal "shipped", p.reload.status
  end

  # --- latest_ship ---

  test "latest_ship returns most recent ship" do
    p = projects(:one)
    p.ships.destroy_all
    s1 = p.ships.create!(user: p.user, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: 1.day.ago)
    s2 = p.ships.create!(user: p.user, devlogged_seconds: 7200, credits_awarded: 2.0, shipped_at: Time.current)
    assert_equal s2, p.latest_ship
  end

  test "latest_ship returns nil when no ships" do
    p = projects(:one)
    p.ships.destroy_all
    assert_nil p.latest_ship
  end

  # --- eligible_for_ship_request? ---

  test "eligible_for_ship_request? returns true when devlogged >= 15 minutes and not shipped" do
    p = projects(:one)
    p.update!(created_at: 1.hour.ago, shipped_at: nil, shipped: false)
    p.devlogs.destroy_all
    p.devlogs.create!(user: p.user, duration_seconds: 900, log_date: Date.current)
    assert_predicate p, :eligible_for_ship_request?
  end

  test "eligible_for_ship_request? returns false when shipped" do
    p = projects(:one)
    p.update!(shipped: true)
    assert_not p.eligible_for_ship_request?
  end

  # --- scope :active ---

  test "scope active returns non-deleted projects" do
    p = projects(:one)
    p.update!(deleted_at: nil)
    assert_includes Project.active, p
  end

  test "scope active excludes soft-deleted projects" do
    p = projects(:one)
    p.update!(deleted_at: Time.current)
    assert_not_includes Project.active, p
  end

  # --- before_create callback ---

  test "before_create sets default status" do
    p = Project.create!(user: users(:one), name: "New", repository_url: "https://example.com")
    assert p.status.present?
  end

  # --- STATUSES constant ---

  test "STATUSES constant includes expected values" do
    assert_includes Project::STATUSES, "pending"
    assert_includes Project::STATUSES, "shipped"
    assert_includes Project::STATUSES, "unshipped"
  end
end
