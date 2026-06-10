module ApplicationHelper
  # Renders text as a multicolor ribbon (see Multicolor) — for the wordmark and
  # big display headings under the brutalist theme. Each color run is a span the
  # theme paints; spaces ride along inside their run.
  def multicolor(text)
    safe_join(
      Multicolor.new(text).segments.map do |str, color|
        content_tag(:span, str, class: "u-ink--#{color}")
      end
    )
  end
end
