# Feeds the authoring tag combobox: existing tag names matching ?q=. Public, like
# the rest of creation (ADR-0005). The query is normalized to the same slug form
# tags are stored in, so "Star Wars" matches "star-wars" — and normalization
# strips any LIKE metacharacters, so the interpolation below is injection-safe.
class TagsController < ApplicationController
  def index
    q = Tag.normalize(params[:q])
    names = q ? Tag.where("name LIKE ?", "%#{q}%").order(:name).limit(10).pluck(:name) : []
    render json: names
  end
end
