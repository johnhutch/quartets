module ApplicationHelper
  # The site-wide default <meta name="description"> — used on the homepage and
  # any page that doesn't set its own.
  SITE_DESCRIPTION = "Create and play Connections-style puzzles.".freeze

  # SEO description for a puzzle page. Prefer the author's shareable blurb (it's
  # purpose-built — "shows when shared"); otherwise a generated, spoiler-free
  # line. The same string feeds <meta name="description">, og:, and twitter: so
  # the SERP snippet and social unfurl agree.
  def puzzle_meta_description(puzzle)
    return puzzle.description.squish if puzzle.description.present?

    by = puzzle.author_name.present? ? " by #{puzzle.author_name}" : ""
    "A Connections-style puzzle (but better)#{by}. Play it free on Quartets."
  end

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
    save: 'M5 4.5h9.879a1.5 1.5 0 0 1 1.06.44l3.122 3.12a1.5 1.5 0 0 1 .439 1.061V18a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 18V6A1.5 1.5 0 0 1 5 4.5z M7.5 4.5v4h7v-4 M7.5 19.5v-6h9v6',
    edit: 'M16.862 4.487l1.687-1.688a1.875 1.875 0 0 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931z M19.5 7.125 16.862 4.487 M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10',
    menu: 'M3.75 6.75h16.5 M3.75 12h16.5 M3.75 17.25h16.5',
    close: 'M6 18 18 6 M6 6l12 12',
    filter: 'M12 3c2.755 0 5.455.232 8.083.678.533.09.917.556.917 1.096v1.044a2.25 2.25 0 0 1-.659 1.591l-5.432 5.432a2.25 2.25 0 0 0-.659 1.591v2.927a2.25 2.25 0 0 1-1.244 2.013L9.75 21v-6.568a2.25 2.25 0 0 0-.659-1.591L3.659 7.409A2.25 2.25 0 0 1 3 5.818V4.774c0-.54.384-1.006.917-1.096A48.32 48.32 0 0 1 12 3z',
    clear: 'M9.75 9.75l4.5 4.5 M14.25 9.75l-4.5 4.5 M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z'
  }.freeze

  # North-east arrow pinned to *text* presentation. iOS otherwise renders a bare
  # ↗ as an emoji block; the U+FE0E variation selector forces the skinny glyph,
  # matching desktop. Used anywhere the "↗" appears in copy.
  def ne_arrow
    "↗\u{FE0E}"
  end

  # On the puzzle authoring form (new *or* edit — autosave rewrites the URL to the
  # edit path mid-create). The nav drops its "Create" shortcut here; you're already
  # making one.
  def authoring_page?
    controller_name == "puzzles" && action_name.in?(%w[new edit])
  end

  # The homepage is a launchpad with its own fronted nav — the global topbar is
  # suppressed there (see the layout). Sub-pages keep the topbar.
  def home_page?
    controller_name == "home"
  end

  # On-page rendering of an EmojiCube: each emoji square becomes a CSS block in
  # OUR palette, so the visible cube always matches the site's colors exactly —
  # the raw 🟨🟩🟦🟪 live only in the copyable share text, where emoji are the
  # only portable option. Decorative (aria-hidden); the share text is the
  # accessible artifact.
  CUBE_CELLS = { "🟨" => "yellow", "🟩" => "green", "🟦" => "blue", "🟪" => "purple" }.freeze

  def cube_grid(cube)
    rows = cube.to_s.split("\n").map do |line|
      cells = line.each_char.map do |square|
        tag.span(class: "m-cube__cell m-cube__cell--#{CUBE_CELLS.fetch(square, 'blank')}")
      end
      tag.span(safe_join(cells), class: "m-cube__row")
    end
    safe_join(rows)
  end

  # Wraps a text input/textarea with an in-box clear (×) button — shown only
  # while the box has something to clear (clearable_controller). `area: true`
  # pins the × to the top corner instead of the vertical middle (textareas).
  def clearable(area: false, &block)
    tag.span(class: class_names("m-clearable", "m-clearable--area": area),
             data: { controller: "clearable", action: "input->clearable#refresh" }) do
      safe_join([
        capture(&block),
        tag.button(icon(:clear), type: "button", class: "m-clearable__clear",
                   hidden: true, "aria-label": "Clear",
                   data: { action: "clearable#clear" })
      ])
    end
  end

  def icon(name)
    paths = ICON_PATHS.fetch(name.to_sym).split(" M").map.with_index do |d, i|
      d = "M#{d}" unless i.zero?
      tag.path(d: d, "stroke-linecap": "round", "stroke-linejoin": "round")
    end
    tag.svg(safe_join(paths),
            class: "m-icon", viewBox: "0 0 24 24", fill: "none",
            stroke: "currentColor", "stroke-width": "1.6", "aria-hidden": "true")
  end

  # Filled trophy silhouette (ADR-0011). The icon helper is stroke-only, so trophies
  # get their own fillable path: one shape, recolored per tier via .m-trophy
  # modifiers (perfect = ink, purple-first = solid purple) — except reverse-rainbow,
  # which fills from a striped purple→blue→green→yellow gradient (hardest at top).
  TROPHY_PATH = "M2.5.5A.5.5 0 0 1 3 0h10a.5.5 0 0 1 .5.5c0 .538-.012 1.05-.034 1.536a3 3 0 1 1-1.133 5.89c-.79 1.865-1.878 2.777-2.833 3.011v2.173l1.425.356c.194.048.377.135.537.255L13.3 15.1a.5.5 0 0 1-.3.9H3a.5.5 0 0 1-.3-.9l1.838-1.379c.16-.12.343-.207.537-.255L6.5 13.11v-2.173c-.955-.234-2.043-1.146-2.833-3.012a3 3 0 1 1-1.132-5.89A33 33 0 0 1 2.5.5zm.099 2.54a2 2 0 0 0 .748 3.806 19.5 19.5 0 0 1-.748-3.806zm10.804 0a19.5 19.5 0 0 1-.748 3.806 2 2 0 0 0 .748-3.806z".freeze
  # Top-to-bottom hard-edged bands: hardest group (purple) at the top, easiest
  # (yellow) at the bottom — the difficulty rainbow, reversed.
  RAINBOW_BANDS = %w[#b04ef0 #4f86f7 #4bd15b #ffd400].freeze # keep in sync with $color-* in _variables.scss

  def trophy(tier)
    tier = tier.to_s
    rainbow = tier == "reverse_rainbow"
    body = tag.path(d: TROPHY_PATH, fill: rainbow ? "url(#trophy-rainbow)" : "currentColor")
    contents = rainbow ? safe_join([rainbow_gradient, body]) : body
    tag.svg(contents,
            class: "m-trophy m-trophy--#{tier.dasherize}",
            viewBox: "0 0 16 16", role: "img",
            "aria-label": t("quartets.trophies.#{tier}"))
  end

  private

  def rainbow_gradient
    stops = RAINBOW_BANDS.each_with_index.flat_map do |color, i|
      [tag.stop(offset: "#{i * 25}%", "stop-color": color),
       tag.stop(offset: "#{(i + 1) * 25}%", "stop-color": color)]
    end
    tag.defs(tag.linearGradient(safe_join(stops),
                                id: "trophy-rainbow", x1: "0", y1: "0", x2: "0", y2: "1"))
  end
end
