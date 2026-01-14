ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Helper to simulate signing in a user in tests
    def sign_in_as(user, password: nil)
      if password
        post admin_login_url, params: { email: user.email, password: password }
      else
        # Dev login available in test env
        post dev_login_url, params: { email: user.email }
      end
    end

    # Add more helper methods to be used by all tests here...

    def assert_audit_created(action:, project:, user: nil)
      a = Audit.where(action: action, project_id: project.id).order(created_at: :desc).first
      assert a.present?, "Expected audit for action=#{action} project=#{project.id}"
      assert a.user == user if user
    end
  end
end
