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

  desc "Ensure a dev admin exists using DEV_ADMIN_EMAIL/DEV_ADMIN_PASSWORD or generate a password if missing. Prints credentials when created/updated."
  task ensure_admin: :environment do
    email = ENV['DEV_ADMIN_EMAIL'].presence || ENV['ADMIN_EMAIL'].presence
    unless email.present?
      puts "Please set DEV_ADMIN_EMAIL or ADMIN_EMAIL environment variable before running this task."
      exit 1
    end

    password = ENV['DEV_ADMIN_PASSWORD'].presence || ENV['ADMIN_PASSWORD'].presence
    generated = false
    if password.blank?
      require 'securerandom'
      password = SecureRandom.base58(16)
      generated = true
    end

    user = User.find_or_initialize_by(email: email)
    user.provider ||= 'dev'
    user.uid ||= "dev-#{SecureRandom.hex(8)}"
    user.name ||= 'Dev Admin'
    user.password = password
    user.role = :admin
    user.save!

    puts "Admin user created/updated: #{user.email} (id=#{user.id})"
    if generated
      puts "Generated password: #{password}"
      puts "Tip: Add DEV_ADMIN_PASSWORD=#{password} to your .env file to avoid regeneration."
    end
  end
end
