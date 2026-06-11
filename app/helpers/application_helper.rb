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

  # Inline SVG icons (Heroicons outline, 24-grid). Sized to 1em via .m-icon so
  # they ride inline with button labels. Decorative — the label carries meaning.
  ICON_PATHS = {
    eye: 'M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z',
    eye_slash: 'M3.98 8.223A10.477 10.477 0 0 0 1.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.451 10.451 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.522 10.522 0 0 1-4.293 5.774M6.228 6.228 3 3m3.228 3.228 3.65 3.65m7.894 7.894L21 21m-3.228-3.228-3.65-3.65m0 0a3 3 0 1 0-4.243-4.243m4.242 4.242L9.88 9.88',
    share: 'M13.5 6H5.25A2.25 2.25 0 0 0 3 8.25v10.5A2.25 2.25 0 0 0 5.25 21h10.5A2.25 2.25 0 0 0 18 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25',
    trash: 'm14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.02-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0',
    save: 'M5 4.5h9.879a1.5 1.5 0 0 1 1.06.44l3.122 3.12a1.5 1.5 0 0 1 .439 1.061V18a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 18V6A1.5 1.5 0 0 1 5 4.5z M7.5 4.5v4h7v-4 M7.5 19.5v-6h9v6'
  }.freeze

  def icon(name)
    paths = ICON_PATHS.fetch(name.to_sym).split(" M").map.with_index do |d, i|
      d = "M#{d}" unless i.zero?
      tag.path(d: d, "stroke-linecap": "round", "stroke-linejoin": "round")
    end
    tag.svg(safe_join(paths),
            class: "m-icon", viewBox: "0 0 24 24", fill: "none",
            stroke: "currentColor", "stroke-width": "1.6", "aria-hidden": "true")
  end
end
