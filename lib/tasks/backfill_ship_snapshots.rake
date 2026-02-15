namespace :data do
  desc "Backfill hackatime_ids_snapshot on existing ships from their project's current hackatime_ids"
  task backfill_ship_snapshots: :environment do
    puts "Backfilling hackatime_ids_snapshot for existing ships..."
    
    count = 0
    Ship.where(hackatime_ids_snapshot: nil).find_each do |ship|
      # Use the current hackatime_ids from the project 
      # (best effort for historical ships)
      ship.hackatime_ids_snapshot = ship.project&.hackatime_ids
      ship.save!(validate: false)
      count += 1
      print "." if count % 100 == 0
    end
    
    puts "\nBackfilled #{count} ships."
  end
end
