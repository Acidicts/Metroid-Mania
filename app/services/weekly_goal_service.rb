# frozen_string_literal: true

# Service object responsible for evaluating the weekly (Monday–Sunday) devlog
# goal and awarding a random contributor a free "prize" order when the
# community logs at least 100 h in that window.
#
# The main entrypoint is `check_and_award!`.  It returns the created +Order+
# when a winner is selected, or +false+ when nothing happened.  The method is
# idempotent for a given Monday–Sunday week.
class WeeklyGoalService
  THRESHOLD_SECONDS = 100.hours.to_i

  class << self
    # How many seconds are required to trigger the prize.  Overridable via
    # SiteSetting for testing or special events.
    def threshold
      (SiteSetting.get("weekly_goal_threshold_seconds") || THRESHOLD_SECONDS).to_i
    end

    # Monday 00:00:00 of the current calendar week (locale-independent).
    def week_start
      Time.current.beginning_of_week(:monday)
    end

    # Sunday 23:59:59 of the current calendar week.
    def week_end
      Time.current.end_of_week(:monday)
    end

    # Find or lazily create the free "prize" product used for weekly awards.
    # The product has zero notch cost and is hidden from the public storefront
    # so it doesn't appear as something regular users can buy.
    def prize_product
    # search case‑insensitively to avoid duplicate products when someone
    # manually creates "Prize" instead of "prize".  `first_or_create!`
    # with a raw SQL condition handles both existing and missing records.
    Product.where("lower(name) = ?", "prize").first_or_create! do |p|
      p.name        = "prize"   # ensure correct casing when inserting
      p.description = "Weekly community goal prize – awarded automatically"
      p.notch_cost  = 0
      p.stock       = 0
      p.limited     = false
      p.show        = false
      p.price_currency = 0
    end.tap do |p|
      # normalize the name of any existing row so future queries stay simple
      if p.name != "prize"
        p.update!(name: "prize")
      end
    end
    rescue => e
      Rails.logger.error("WeeklyGoalService: could not find/create prize product – #{e.message}")
      nil
    end

    # ISO8601 timestamp stored in SiteSettings recording the last award.
    def last_awarded_at
      val = SiteSetting.get("weekly_goal_last_awarded_at")
      val.present? ? Time.parse(val) : nil
    end

    def set_last_awarded(time = Time.current)
      SiteSetting.set("weekly_goal_last_awarded_at", time.utc.iso8601)
    end

    # Evaluate the goal and award a prize if the threshold has been reached.
    # Returns the new +Order+ or +false+.
    def check_and_award!
      now = Time.current
      start = week_start

      # already awarded this Mon–Sun week?
      if last_awarded_at && last_awarded_at >= start
        Rails.logger.debug("WeeklyGoalService: already awarded for week starting #{start}")
        return false
      end

      total = Devlog.total_duration_seconds(start..now)
      if total < threshold
        Rails.logger.debug("WeeklyGoalService: goal not reached (#{total} < #{threshold})")
        return false
      end

      product = prize_product
      unless product
        Rails.logger.warn("WeeklyGoalService: threshold met but prize product unavailable")
        return false
      end

      winner = User.joins(:devlogs)
                   .where(devlogs: { ship_request_id: nil,
                                     log_date: start.to_date..week_end.to_date })
                   .distinct
                   .order(Arel.sql("RANDOM()"))
                   .first
      unless winner
        Rails.logger.warn("WeeklyGoalService: no eligible user despite meeting goal")
        return false
      end

      order = create_prize_order_for(winner)

      set_last_awarded(now)

      Audit.create!(user: nil, project: nil, action: "weekly_goal_awarded",
                    details: {
                      week_start:    start,
                      total_seconds: total,
                      winner_id:     winner.id,
                      order_id:      order.id
                    })

      Rails.logger.info("WeeklyGoalService: awarded prize to user #{winner.id} (order #{order.id})")
      order
    end
  # Force a prize award regardless of threshold or whether the week has
  # already been awarded.  This is primarily used by admins when the normal
  # automated check fails or when a manual giveaway is desired.  Returns the
  # created +Order+ or +false+ if no eligible user exists.
  def force_award!
    product = prize_product
    unless product
      Rails.logger.warn("WeeklyGoalService: prize product unavailable for force_award")
      return false
    end

    winner = pick_winner
    unless winner
      Rails.logger.warn("WeeklyGoalService: no eligible user for force_award")
      return false
    end

    order = create_prize_order_for(winner)
    set_last_awarded(Time.current)

    Audit.create!(user: nil, project: nil, action: "weekly_goal_awarded",
                  details: {
                    week_start:    week_start,
                    total_seconds: Devlog.total_duration_seconds(week_start..Time.current),
                    winner_id:     winner.id,
                    order_id:      order.id,
                    forced:        true
                  })

    Rails.logger.info("WeeklyGoalService: force-awarded prize to user #{winner.id} (order #{order.id})")
    order
  end

  private

  # Pick a random user who logged at least one devlog during the current
  # week.  Mirrors the query used by +check_and_award!+.
  def pick_winner
    User.joins(:devlogs)
        .where(devlogs: { ship_request_id: nil,
                          log_date: week_start.to_date..week_end.to_date })
        .distinct
        .order(Arel.sql("RANDOM()"))
        .first
  end

  # Build and persist a free prize order for the specified user.  Sharing
  # logic between +check_and_award!+ and +force_award!+ keeps the behaviour
  # consistent.
  def create_prize_order_for(winner)
    Order.create!(
      user: winner,
      product: prize_product,
      cost: 0.0,
      status: (Order.respond_to?(:statuses) ? Order.statuses["pending"] : "pending")
    )
  end
  end
end
