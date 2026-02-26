namespace :goals do
  desc "Evaluate the weekly devlog goal and award a prize if reached"
  task check: :environment do
    result = WeeklyGoalService.check_and_award!
    if result.is_a?(Order)
      puts "Weekly goal reached and awarded to user ##{result.user_id}, order ##{result.id}."
    elsif result == false
      puts "Weekly goal did not trigger an award."
    else
      # should never happen, but be defensive
      puts "WeeklyGoalService returned unexpected value: \\#{result.inspect}"
    end
  end
end
