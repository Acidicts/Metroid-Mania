namespace :admin do
  desc "Backfill ShipRequest.credits_awarded from matching Ships when missing"
  task backfill_ship_requests: :environment do
    puts "Starting backfill of ShipRequest.credits_awarded..."
    count = 0

    ShipRequest.where(credits_awarded: [nil, '']).find_each do |sr|
      project = sr.project
      next unless project

      # find first ship on or after the request time
      matching_ship = project.ships.where('shipped_at >= ?', sr.requested_at).order(:shipped_at).first
      if matching_ship
        sr.update!(credits_awarded: matching_ship.credits_awarded, status: (sr.status == 'pending' ? 'approved' : sr.status), approved_at: (sr.approved_at || matching_ship.shipped_at), processed_by: (sr.processed_by || matching_ship.user))
        Audit.create!(user: current_user = matching_ship.user, project: project, action: 'backfill_ship_request', details: { ship_id: matching_ship.id, ship_request_id: sr.id, credits_awarded: matching_ship.credits_awarded }) rescue nil
        count += 1
        puts "Backfilled ShipRequest #{sr.id} from Ship #{matching_ship.id} (credits=#{matching_ship.credits_awarded})"
      else
        # no matching ship found; skip
      end
    end

    puts "Backfilled #{count} ShipRequests"
  end
end