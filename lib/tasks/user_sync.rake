namespace :users do
  desc "Backfill User.amount_spent from Orders and recalculate user currency"
  task backfill_amount_spent_and_currency: :environment do
    puts "Backfilling user.amount_spent from Orders and recalculating currency..."
    User.find_each do |u|
      begin
        total_spent = u.orders.where.not(status: 'denied').sum(:cost).to_f
        u.update!(amount_spent: total_spent)
        u.recalculate_currency!
        puts "User ##{u.id}: amount_spent=#{total_spent} currency=#{u.currency}"
      rescue => e
        puts "Failed for User ##{u.id}: #{e.message}"
      end
    end
    puts "Done."
  end
end
