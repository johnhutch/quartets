# The XML sitemap — how search + AI-citation crawlers discover the catalog. Only
# public, indexable URLs: published puzzles, static pages, and profiles of people
# who've published something. Unlisted/incomplete puzzles carry noindex and stay
# out. Rendered on the fly (small catalog); cache if it ever grows.
class SitemapController < ApplicationController
  def index
    @puzzles = Puzzle.published.select(:share_token, :updated_at).order(updated_at: :desc)
    @handles = User.where(id: Puzzle.published.select(:user_id)).pluck(:handle).compact
    render layout: false
  end
end
