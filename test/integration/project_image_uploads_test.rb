require "test_helper"

class ProjectImageUploadsTest < ActionDispatch::IntegrationTest
  test "owner can upload image on create" do
    owner = users(:one)
    sign_in_as(owner)

    image_path = create_sample_image("project_test.png")
    file = Rack::Test::UploadedFile.new(image_path, "image/png")

    post projects_url, params: { project: { name: "UploadTest", repository_url: "https://example.com/repo", image: file } }

    assert_response :redirect
    project = Project.last
    assert project.image.attached?, "Expected image to be attached to the project"
  end

  test "owner can remove image on update" do
    owner = users(:one)
    sign_in_as(owner)

    image_path = create_sample_image("project_update.png")
    file = Rack::Test::UploadedFile.new(image_path, "image/png")

    project = owner.projects.create!(name: "WithImage", repository_url: "https://example.com/repo")
    project.image.attach(io: File.open(image_path), filename: "project_update.png", content_type: "image/png")
    assert project.image.attached?

    patch project_url(project), params: { project: { remove_image: "1" } }
    assert_redirected_to project_url(project)
    assert_not project.reload.image.attached?
  end

  test "updating without uploading a new image preserves existing attachment" do
    owner = users(:one)
    sign_in_as(owner)

    image_path = create_sample_image("preserve.png")
    project = owner.projects.create!(name: "PreserveImage", repository_url: "https://example.com/repo")
    project.image.attach(io: File.open(image_path), filename: "preserve.png", content_type: "image/png")
    assert project.image.attached?

    # Update without providing `image` param at all — should keep existing attachment
    patch project_url(project), params: { project: { name: "Changed name" } }
    assert_redirected_to project_url(project)
    assert project.reload.image.attached?

    # Also simulate an empty image param being sent (defensive) — should NOT remove attachment
    patch project_url(project), params: { project: { name: "Changed again", image: "" } }
    assert_redirected_to project_url(project)
    assert project.reload.image.attached?
  end

  test "edit form pre-fills existing image preview and filename" do
    owner = users(:one)
    sign_in_as(owner)

    image_path = create_sample_image("prefill.png")
    project = owner.projects.create!(name: "PrefillImage", repository_url: "https://example.com/repo")
    project.image.attach(io: File.open(image_path), filename: "prefill.png", content_type: "image/png")

    get edit_project_url(project)
    assert_response :success

    # the preview element and file input should be present in the edit form HTML
    assert_select "img.file-input-preview"
    assert_select "input[type=file][name='project[image]']"
    assert_includes response.body, "prefill.png"
  end

  test "show page includes og:image when image attached" do
    owner = users(:one)
    sign_in_as(owner)

    project = owner.projects.create!(name: "OgTest", repository_url: "https://example.com/repo", description: "Project for OG testing")
    # attach blob directly
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "og.png", content_type: "image/png")
    project.image.attach(blob)

    get project_url(project)
    assert_response :success
    # page should start with a proper DOCTYPE so social crawlers can parse it
    assert_match /^<!DOCTYPE html>/, response.body
    assert_select "meta[property='og:title']", 1
    assert_equal project.name, css_select("meta[property='og:title']").first.attributes["content"].value

    assert_select "meta[property='og:description']", 1
    assert_equal project.description.to_s.truncate(200), css_select("meta[property='og:description']").first.attributes["content"].value

    assert_select "meta[name='twitter:card']", 1
    assert_equal "summary_large_image", css_select("meta[name='twitter:card']").first.attributes["content"].value

    assert_select "meta[property='og:image']", 1
    img_meta = css_select("meta[property='og:image']").first.attributes["content"].value
    assert_match %r{https?://}, img_meta

    # host should reflect the request, not the default_url_options value.
    assert_includes img_meta, request.host
    assert_not_includes img_meta, "localhost" if request.host != "localhost"

    assert_includes img_meta, blob.signed_id.to_s

    # actual banner image should be rendered with the same URL
    assert_select "img.project-media__img", 1
    img_src = css_select("img.project-media__img").first.attributes["src"].value
    assert_equal img_meta, img_src

    # when description is blank we still want a fallback OG description
    project2 = owner.projects.create!(name: "NoDesc", repository_url: "https://example.com/repo", description: nil)
    blob2 = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "og2.png", content_type: "image/png")
    project2.image.attach(blob2)
    get project_url(project2)
    assert_response :success
    desc = css_select("meta[property='og:description']").first.attributes["content"].value
    assert desc.present?, "expected fallback description when none provided"

    assert_select "meta[property='og:image']", 1
    img_meta2 = css_select("meta[property='og:image']").first.attributes["content"].value
    assert_includes img_meta2, blob2.signed_id.to_s
  end
end
