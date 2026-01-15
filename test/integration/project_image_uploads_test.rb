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
end
