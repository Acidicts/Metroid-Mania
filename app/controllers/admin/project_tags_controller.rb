module Admin
  class ProjectTagsController < Admin::ApplicationController
    before_action :require_admin
    before_action :set_project_tag, only: [ :show, :edit, :update, :destroy ]

    def index
      @project_tags = ProjectTag.all.order(:tag_string)
    end

    def show
    end

    def new
      @project_tag = ProjectTag.new
    end

    def create
      @project_tag = ProjectTag.new(project_tag_params)
      if @project_tag.save
        redirect_to admin_project_tags_path, notice: "Project tag was successfully created."
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @project_tag.update(project_tag_params)
        redirect_to admin_project_tags_path, notice: "Project tag was successfully updated."
      else
        render :edit
      end
    end

    def destroy
      @project_tag.destroy
      redirect_to admin_project_tags_path, notice: "Project tag was deleted."
    end

    private

    def set_project_tag
      @project_tag = ProjectTag.find(params[:id])
    end

    def project_tag_params
      # callers and forms should work with the nicer `tag` alias, but the
      # underlying column is still `tag_string`.  permit both here so that
      # existing tests/clients that reference `tag_string` won’t break.
      params.require(:project_tag).permit(:tag, :tag_string, :project_id)
    end
  end
end
