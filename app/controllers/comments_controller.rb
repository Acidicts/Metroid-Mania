class CommentsController < ApplicationController
  before_action :set_comment, only: %i[ show edit update destroy ]
  before_action :ensure_editable, only: %i[ edit update destroy ]
  before_action :ensure_user_not_fraudulent, only: %i[ create ]

  # GET /comments or /comments.json
  def index
    @comments = Comment.all
  end

  # GET /comments/1 or /comments/1.json
  def show
  end

  # GET /comments/new
  def new
    @comment = Comment.new
  end

  # GET /comments/1/edit
  def edit
  end

  # POST /comments or /comments.json
  def create
    # Disallow non-admins from creating comments tied to a Ship
    if comment_params[:ship_id].present? && !(defined?(current_user) && current_user&.admin?)
      redirect_back fallback_location: root_path, alert: "Only admins may comment on ships." and return
    end

    @comment = Comment.new(comment_params)
    @comment.user = current_user if defined?(current_user) && @comment.user.nil?

    if @comment.save
      redirect_back fallback_location: root_path, notice: "Comment created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /comments/1 or /comments/1.json
  def update
    respond_to do |format|
      if @comment.update(comment_params)
        format.html { redirect_to @comment, notice: "Comment was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @comment }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @comment.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /comments/1 or /comments/1.json
  def destroy
    @comment.destroy!

    respond_to do |format|
      format.html { redirect_to comments_path, notice: "Comment was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_comment
      @comment = Comment.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def comment_params
      params.require(:comment).permit(:message, :devlog_id, :ship_id)
    end

    def ensure_editable
      unless @comment.editable_by?(current_user)
        respond_to do |format|
          format.html { redirect_back fallback_location: root_path, alert: "You are not permitted to perform that action on this comment." }
          format.json { render json: { error: "You are not permitted to perform that action on this comment." }, status: :forbidden }
        end
      end
    end
end
