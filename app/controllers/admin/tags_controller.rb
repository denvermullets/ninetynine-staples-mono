module Admin
  class TagsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin
    before_action :set_tag, only: %i[edit update destroy]

    def index
      @tags = Tag.alphabetical
    end

    def new
      @tag = Tag.new
    end

    def create
      @tag = Tag.new(tag_params)
      if @tag.save
        redirect_to admin_tags_path, notice: 'Tag created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @tag.update(tag_params)
        redirect_to admin_tags_path, notice: 'Tag updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @tag.destroy
      redirect_to admin_tags_path, notice: 'Tag deleted successfully.'
    end

    private

    def set_tag
      @tag = Tag.find(params[:id])
    end

    def ensure_admin
      redirect_to(root_path, alert: 'Access denied') unless current_user&.role.to_i == 9001
    end

    def tag_params
      params.require(:tag).permit(:name, :color, :description)
    end
  end
end
