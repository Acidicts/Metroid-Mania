namespace :dev do
  desc "Create or update a dev admin user from ENV vars ADMIN_EMAIL and ADMIN_PASSWORD"
  task create_admin: :environment do
    email = ENV['ADMIN_EMAIL']
    password = ENV['ADMIN_PASSWORD']

    if email.blank? || password.blank?
      puts "Please set ADMIN_EMAIL and ADMIN_PASSWORD environment variables before running this task."
      exit 1
    end

    user = User.find_or_initialize_by(email: email)
    user.provider ||= 'dev'
    user.uid ||= "dev-#{SecureRandom.hex(8)}"
    user.name ||= 'Dev Admin'
    user.password = password
    user.role = :admin
    user.save!

    puts "Admin user created/updated: #{user.email} (id=#{user.id})"
  end
end
