require "test_helper"

class ProjectImageUploadsTest < ActionDispatch::IntegrationTest
  test "owner can upload image on create" do
    owner = users(:one)
    sign_in_as(owner)

    image_path = create_sample_image('project_test.png')
    file = Rack::Test::UploadedFile.new(image_path, 'image/png')

    post projects_url, params: { project: { name: 'UploadTest', repository_url: 'https://example.com/repo', image: file } }

    assert_response :redirect
    project = Project.last
    assert project.image.attached?, "Expected image to be attached to the project"
  end

  test "owner can remove image on update" do
    owner = users(:one)
    sign_in_as(owner)

    image_path = create_sample_image('project_update.png')
    file = Rack::Test::UploadedFile.new(image_path, 'image/png')

    project = owner.projects.create!(name: 'WithImage', repository_url: 'https://example.com/repo')
    project.image.attach(io: File.open(image_path), filename: 'project_update.png', content_type: 'image/png')
    assert project.image.attached?

    patch project_url(project), params: { project: { remove_image: '1' } }
    assert_redirected_to project_url(project)
    assert_not project.reload.image.attached?
  end

  test "updating without uploading a new image preserves existing attachment" do
    owner = users(:one)
    sign_in_as(owner)

    image_path = create_sample_image('preserve.png')
    project = owner.projects.create!(name: 'PreserveImage', repository_url: 'https://example.com/repo')
    project.image.attach(io: File.open(image_path), filename: 'preserve.png', content_type: 'image/png')
    assert project.image.attached?

    # Update without providing `image` param at all — should keep existing attachment
    patch project_url(project), params: { project: { name: 'Changed name' } }
    assert_redirected_to project_url(project)
    assert project.reload.image.attached?

    # Also simulate an empty image param being sent (defensive) — should NOT remove attachment
    patch project_url(project), params: { project: { name: 'Changed again', image: '' } }
    assert_redirected_to project_url(project)
    assert project.reload.image.attached?
  end

  test "edit form pre-fills existing image preview and filename" do
    owner = users(:one)
    sign_in_as(owner)

    image_path = create_sample_image('prefill.png')
    project = owner.projects.create!(name: 'PrefillImage', repository_url: 'https://example.com/repo')
    project.image.attach(io: File.open(image_path), filename: 'prefill.png', content_type: 'image/png')

    get edit_project_url(project)
    assert_response :success

    # the preview element and filename should be present in the edit form HTML
    assert_includes response.body, 'file-input-preview'
    assert_includes response.body, 'file-input-filename'
    assert_includes response.body, 'prefill.png'
  end
end
