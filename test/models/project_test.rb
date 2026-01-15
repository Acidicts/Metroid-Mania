require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "shipped? returns false when attribute missing (defensive_behavior)" do
    project = Project.new
    # Simulate missing column / attribute by overriding has_attribute? on the instance
    def project.has_attribute?(attr)
      false
    end

    assert_not project.shipped?
  end

  test "shipped? reflects DB value when column exists" do
    project = projects(:one)

    project.update!(shipped: true)
    assert project.shipped?, "Expected shipped? to return true after setting shipped: true"

    project.update!(shipped: false)
    assert_not project.shipped?, "Expected shipped? to return false after setting shipped: false"
  end

  test "hackatime ids must be unique across projects" do
    p1 = projects(:one)
    p2 = projects(:two)

    p1.update!(hackatime_ids: ['Alpha Project'])
    p2.hackatime_ids = ['Alpha Project']
    assert_not p2.valid?
    assert_match /already linked/, p2.errors[:hackatime_ids].join(', ')
  end
end
