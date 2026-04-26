require "test_helper"

class AccessoryTest < ActiveSupport::TestCase
  test "image_url returns ActiveStorage path when attachment exists" do
    accessory = Accessory.new(name: "Hat")
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "hat.png", content_type: "image/png")
    accessory.image.attach(blob)

    assert accessory.image.attached?
    assert_match %r{/rails/active_storage/blobs/}, accessory.image_url
  end
end
