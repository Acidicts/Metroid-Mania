require "test_helper"
require "tempfile"

class Admin::RsvpControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_as users(:admin)

    get admin_rsvp_url
    assert_response :success
  end

  test "imports rsvps from csv" do
    sign_in_as users(:admin)
    csv_file = create_csv_file("slack_id,name\nUCSV001,Csv One\nUCSV002,Csv Two\n")

    begin
      assert_difference("Rsvp.count", 2) do
        post admin_import_rsvp_url, params: { csv_file: fixture_file_upload(csv_file.path, "text/csv") }
      end
    ensure
      csv_file.close!
    end

    assert_redirected_to admin_rsvp_url
    assert_equal "Imported 2 RSVP(s).", flash[:notice]
  end

  test "import requires csv file" do
    sign_in_as users(:admin)

    assert_no_difference("Rsvp.count") do
      post admin_import_rsvp_url
    end

    assert_redirected_to admin_rsvp_url
    assert_equal "Please choose a CSV file to import.", flash[:alert]
  end

  test "import requires slack_id and name headers" do
    sign_in_as users(:admin)
    csv_file = create_csv_file("email,name\none@example.com,User One\n")

    begin
      assert_no_difference("Rsvp.count") do
        post admin_import_rsvp_url, params: { csv_file: fixture_file_upload(csv_file.path, "text/csv") }
      end
    ensure
      csv_file.close!
    end

    assert_redirected_to admin_rsvp_url
    assert_equal "CSV must include headers: slack_id, name.", flash[:alert]
  end

  private

  def create_csv_file(contents)
    tempfile = Tempfile.new([ "rsvp-import", ".csv" ])
    tempfile.write(contents)
    tempfile.rewind
    tempfile
  end
end
