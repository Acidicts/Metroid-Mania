namespace :admin do
  desc "Backfill ShipRequest.credits_awarded from matching Ships when missing"
  task backfill_ship_requests: :environment do
    puts "Starting backfill of ShipRequest.credits_awarded..."
    count = 0

    ShipRequest.where(credits_awarded: [ nil, "" ]).find_each do |sr|
      project = sr.project
      next unless project

      # find first ship on or after the request time
      matching_ship = project.ships.where("shipped_at >= ?", sr.requested_at).order(:shipped_at).first
      if matching_ship
        # ensure multiplier is carried forward when possible
        sr_attrs = {
          credits_awarded: matching_ship.credits_awarded,
          status: (sr.status == "pending" ? "approved" : sr.status),
          approved_at: (sr.approved_at || matching_ship.shipped_at),
          processed_by: (sr.processed_by || matching_ship.user)
        }
        sr_attrs[:multiplier] = matching_ship.multiplier if matching_ship.has_attribute?(:multiplier)
        sr.update!(sr_attrs)

        # backfill ship multiplier if missing based on request
        if matching_ship.has_attribute?(:multiplier) && sr.multiplier.present? && matching_ship.multiplier.to_f <= 0
          matching_ship.update!(multiplier: sr.multiplier)
        end

        Audit.create!(user: current_user = matching_ship.user, project: project, action: "backfill_ship_request", details: { ship_id: matching_ship.id, ship_request_id: sr.id, credits_awarded: matching_ship.credits_awarded }) rescue nil
        count += 1
        puts "Backfilled ShipRequest #{sr.id} from Ship #{matching_ship.id} (credits=#{matching_ship.credits_awarded})"
      else
        # no matching ship found; skip
      end
    end

    # ensure any ships still missing multipliers get them from their requests
    ShipRequest.where.not(multiplier: [ nil, "" ]).find_each do |sr|
      puts "considering request ##{sr.id} (mult=#{sr.multiplier.inspect}, ship_id=#{sr.ship_id})"
      ship = Ship.find_by(id: sr.ship_id)
      unless ship
        ship = sr.project&.ships&.where("shipped_at >= ?", sr.requested_at)&.order(:shipped_at)&.first
        puts "  looked up ship by time: #{ship&.id.inspect}"
      else
        puts "  found ship by id: #{ship.id} multip=#{ship.multiplier.inspect}"
      end
      # treat a zero/blank multiplier as needing fill; previous code used
      # `blank?` which ignores 0.0 because the column is float.  We want
      # to update when the stored value is nil or <= 0.
      if ship && ship.has_attribute?(:multiplier) && ship.multiplier.to_f <= 0
        ship.update!(multiplier: sr.multiplier.to_f)
        puts "Backfilled Ship ##{ship.id} multiplier=#{ship.multiplier} from Request ##{sr.id}"
      end
    end

    puts "Backfilled #{count} ShipRequests"

    # now also ensure ships' charm notch counts match their multiplier
    puts "Adjusting notches on ships based on multiplier..."
    Ship.find_each do |s|
      next unless s.multiplier.present?
      # adjust_notches_for_multiplier is public; force recalculation even if
      # the multiplier didn't just change.
      begin
        s.adjust_notches_for_multiplier(force: true)
      rescue => e
        Rails.logger.error("backfill: failed to adjust notches for Ship ##{s.id}: #{e.message}")
      end
    end
    puts "Finished adjusting ship notches."
  end
end
