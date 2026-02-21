# lib/tasks/validate_all.rake
namespace :data do
  desc "Run model validations for every record. Optionally pass a comma-separated list of model names: rake data:validate_all[User,Order]"
  task :validate_all, [ :models ] => :environment do |t, args|
    # allow passing model names either as comma-separated in the args or via ENV
    names = (args.models || ENV["MODELS"]).to_s.split(",").map(&:strip).reject(&:empty?)
    models = if names.any?
               names.map { |n| n.constantize }
    else
               # validate every concrete AR model; ensure constants are loaded first
               Rails.application.eager_load! unless Rails.application.config.eager_load
               ActiveRecord::Base.descendants.reject(&:abstract_class?)
    end

    models.each do |klass|
      # skip models without corresponding table (e.g. versioning helpers)
      unless klass.table_exists?
        warn "skipping #{klass} (no table)"
        next
      end

      klass.find_each do |record|
        begin
          unless record.valid?
            puts "#{klass}##{record.id} failed: #{record.errors.full_messages.join(', ')}"
          end
        rescue ActiveRecord::StatementInvalid => e
          warn "error validating #{klass}: #{e.message}"
          break
        end
      end
    end
  end
end
