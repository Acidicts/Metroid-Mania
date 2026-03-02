# frozen_string_literal: true

namespace :notch do
  desc <<~DESC
    Backfill notch_remainder_seconds for all projects (or one project via project_id).

    Walks each project's ships in chronological order and simulates the carry-over
    algorithm: 1 notch costs 7200 seconds (2 hours) of devlogged time. Any seconds
    left over after the last ship are stored in notch_remainder_seconds so the next
    ship picks up where the last one left off.

    Usage:
      bin/rails notch:backfill_remainder            # all projects
      bin/rails 'notch:backfill_remainder[42]'      # project id=42 only
      bin/rails 'notch:backfill_remainder[42,true]' # dry-run (no writes)
  DESC
  task :backfill_remainder, [ :project_id, :dry_run ] => :environment do |_t, args|
    dry_run = args[:dry_run].to_s.downcase.in?(%w[true 1 yes])
    puts "(dry-run — no database writes)" if dry_run

    projects = if args[:project_id].present?
                 Project.where(id: args[:project_id])
    else
                 Project.all
    end

    updated = 0
    skipped = 0

    projects.find_each do |project|
      ships = project.ships.order(:shipped_at, :id)

      remainder = 0.0
      ships.each do |ship|
        seconds = ship.devlogged_seconds.to_f + remainder
        raw_notches = seconds / 7200.0
        awarded = raw_notches.floor
        remainder = seconds - (awarded * 7200.0)
      end

      old_remainder = project.notch_remainder_seconds.to_f

      if (remainder - old_remainder).abs < 0.001
        puts "Project #{project.id}: remainder unchanged (#{remainder.round(2)}s) — skip"
        skipped += 1
        next
      end

      puts "Project #{project.id}: #{old_remainder.round(2)}s → #{remainder.round(2)}s " \
           "(#{ships.count} ships)"

      unless dry_run
        project.update_column(:notch_remainder_seconds, remainder)
      end

      updated += 1
    end

    puts "\nDone. Projects updated: #{updated}, unchanged: #{skipped}."
  end
end
