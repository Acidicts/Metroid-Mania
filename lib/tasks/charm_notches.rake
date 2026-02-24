# frozen_string_literal: true

namespace :charm do
  desc "Reconcile charm notches for all users or a specific user"
  task :reconcile, [ :user_id ] => :environment do |_t, args|
    users = if args[:user_id].present?
              User.where(id: args[:user_id])
    else
              User.all
    end

    users.find_each do |u|
      before = u.charm_notches.non_admin.count
      desired = u.reconcile_charm_notches!
      after = u.charm_notches.non_admin.count
      puts "User #{u.id} (#{u.email.presence || 'no-email'}): #{before} -> #{after} desired=#{desired}"
    end
  end
end
