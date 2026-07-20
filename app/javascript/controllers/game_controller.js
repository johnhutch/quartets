import { Controller } from "@hotwired/stimulus"

// The four category colors, in fixed order — drives the mistake boxes (one each).
const GAME_COLORS = ["blue", "green", "yellow", "purple"]

// Per-tile font scale (the CSS --card-fit). ~9 uppercase chars fit a tile at full
// size (with the tile's tight side padding), so anything longer shrinks
// proportionally — floored so it stays legible. Keyed off the longest word (the
// part that can't wrap), not the whole string.
const cardFit = (text) => {
  const longest = Math.max(...text.split(/\s+/).map((w) => w.length))
  return Math.max(0.5, Math.min(1, 9 / longest)).toFixed(2)
}

// The Connections game loop, self-contained — this is the engine we chose to
// build rather than embed (ADR-0003). It reads the puzzle (four groups, each a
// color + category + four words) as a JSON value, shuffles all sixteen tiles,
// and runs the loop: select up to four → submit → reveal the group or count a
// mistake. Mistakes are capped (maxMistakes); find all four groups to win.
// Every guess is recorded and a `game:finished` event fires on game over, so
// Phase 4 can post stats and build the emoji cube.
//
//   data-controller="game"
//   data-game-puzzle-value='{"groups":[{"color":"blue","description":"…","words":[…]}]}'
//   data-game-max-mistakes-value="4"
//
// NOTE: tiles are keyed by their word text, so a puzzle is assumed to have no
// duplicate words across groups (true for NYT-style puzzles). Revisit with a
// per-tile id if that ever stops holding.
export default class extends Controller {
  static targets = ["board", "solved", "status", "toast", "mistakes", "submit"]
  static values = {
    puzzle: Object,
    maxMistakes: { type: Number, default: 4 },
    recordUrl: String,
    eventsUrl: String,
    progressUrl: String,
    saved: Object // a saved half-played game: { guesses: [...], elapsedMs }
  }

  connect() {
    this.groups = {}        // color -> { description, words: [...] }
    this.colorOf = {}       // word  -> color
    this.cards = []         // { word, color } for the tiles still in play
    this.selected = []      // selected words (max 4)
    this.solvedColors = []  // colors already found
    this.mistakes = 0
    this.guesses = []       // [{ words: [...], colors: [...], t }]
    this.wrongPicks = new Set() // sorted word-sets already guessed wrong (resubmit guard)
    this.over = false
    this.startTime = null   // set on the first tile tap; the clock for timing
    this.resumed = false    // true when rehydrated from a saved game
    this.resumedElapsed = 0 // where the saved play clock left off (ms)

    this.puzzleValue.groups.forEach((group) => {
      this.groups[group.color] = { description: group.description, words: group.words }
      group.words.forEach((word) => {
        this.colorOf[word] = group.color
        this.cards.push({ word, color: group.color })
      })
    })

    // Wipe anything a prior play left in the DOM before rebuilding. render() only
    // clears the board; a Turbo-restored snapshot can also carry injected solved
    // rows, the win/lose stamp, and the is-over class. The no-cache meta on the
    // interactive board should prevent that snapshot, but resetting here means a
    // stale one can never resurrect a broken hybrid board.
    if (this.hasSolvedTarget) this.solvedTarget.innerHTML = ""
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ""
      this.statusTarget.classList.remove("is-visible")
    }
    if (this.hasToastTarget) this.toastTarget.classList.remove("is-visible")
    this.element.classList.remove("is-over")
    this.element.querySelectorAll(".m-game__share, .m-awards, .m-rating").forEach((n) => n.remove())

    this.shuffleCards()
    if (this.savedValue.guesses?.length) this.restore(this.savedValue)
    this.render()
    this.renderMistakes()
  }

  // Rehydrate a saved half-played game (the server-derived guess log from
  // PlayState): replay each guess into our state — solved groups come off the
  // board, wrong guesses burn their mistake and re-arm the resubmit guard — so
  // the restored board is exactly the one the player walked away from.
  restore({ guesses, elapsedMs }) {
    this.resumed = true
    this.resumedElapsed = elapsedMs || 0
    guesses.forEach((guess) => {
      const colors = guess.colors
      const correct = colors.every((color) => color === colors[0])
      this.guesses.push({ words: guess.words, colors, t: guess.t ?? null })
      if (correct) {
        this.solvedColors.push(colors[0])
        this.cards = this.cards.filter((card) => card.color !== colors[0])
        this.renderSolved(colors[0])
      } else {
        this.wrongPicks.add([...guess.words].sort().join("|"))
        this.mistakes += 1
      }
    })
  }

  // --- player actions ---------------------------------------------------

  // Slide every tile to its new cell instead of popping. We reuse the live tile
  // elements (no innerHTML rebuild) and FLIP-animate: record where each tile is,
  // re-append them in the shuffled order so the CSS grid reflows them, then play
  // each from its old position to its new one. `composite: "add"` layers the
  // slide on top of a selected tile's lift transform so selections survive.
  shuffle() {
    if (this.over) return

    const tiles = [...this.boardTarget.querySelectorAll(".m-card")]
    const first = new Map(tiles.map((el) => [el, el.getBoundingClientRect()]))
    const byWord = new Map(tiles.map((el) => [el.dataset.word, el]))

    this.shuffleCards()
    this.cards.forEach((card) => this.boardTarget.appendChild(byWord.get(card.word)))

    if (this.reducedMotion) return
    tiles.forEach((el) => {
      const a = first.get(el)
      const b = el.getBoundingClientRect()
      const dx = a.left - b.left
      const dy = a.top - b.top
      if (!dx && !dy) return
      el.animate(
        [{ transform: `translate(${dx}px, ${dy}px)` }, { transform: "translate(0, 0)" }],
        { duration: 320, easing: "cubic-bezier(0.34, 1.2, 0.5, 1)", composite: "add" }
      )
    })
  }

  // Settle each selected tile with the same un-click animation, cascaded 0.2s
  // apart (left-to-right by DOM order). State clears immediately; the staggered
  // class removal is purely visual. Reduced motion → all at once, no stagger.
  deselect() {
    if (this.over) return

    const tiles = [...this.boardTarget.querySelectorAll(".m-card.is-selected")]
    this.selected = []
    if (this.hasSubmitTarget) this.submitTarget.disabled = true

    const step = this.reducedMotion ? 0 : 50
    tiles.forEach((tile, i) => {
      setTimeout(() => {
        // Skip if the player re-selected this tile mid-cascade.
        if (this.selected.includes(tile.dataset.word)) return
        tile.classList.remove("is-selected")
        tile.removeAttribute("aria-pressed")
      }, i * step)
    })
  }

  submit() {
    if (this.over || this.selected.length !== 4) return

    // A wrong guess stays selected, so the same four sit one tap from being
    // resubmitted — tell the player instead of burning a second mistake.
    const pick = [...this.selected].sort().join("|")
    if (this.wrongPicks.has(pick)) {
      this.setStatus("You already made that guess")
      return
    }

    const colors = this.selected.map((word) => this.colorOf[word])
    const correct = colors.every((color) => color === colors[0])
    // Log the picked words + the true color of each, plus `t` (ms since the clock
    // started) for per-guess timing. Correctness is derived from the colors
    // server-side (the Guess value object), so we don't store it — the cube,
    // common-mistakes, and trophies all read it back off the colors.
    this.guesses.push({ words: [...this.selected], colors, t: this.elapsedMs() })

    if (correct) {
      this.lockGroup(colors[0])
    } else {
      this.wrongPicks.add(pick)
      this.registerMistake(colors)
    }

    // Persist the mid-game state so leaving and coming back resumes. Game over
    // records the finished play instead (record()), which spends the save.
    if (!this.over) this.saveProgress()
  }

  // --- internals --------------------------------------------------------

  // Toggle selection on the live tile (no full re-render) so the CSS lift/tilt
  // actually animates — a rebuilt element would pop in already-selected.
  toggle(word, tile) {
    if (this.over) return
    this.markStarted() // first tap starts the clock + beacons game_started
    const at = this.selected.indexOf(word)
    if (at >= 0) {
      this.selected.splice(at, 1)
      tile.classList.remove("is-selected")
      tile.removeAttribute("aria-pressed")
    } else if (this.selected.length < 4) {
      this.selected.push(word)
      tile.classList.add("is-selected")
      tile.setAttribute("aria-pressed", "true")
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = this.over || this.selected.length !== 4
    }
  }

  lockGroup(color) {
    this.solvedColors.push(color)
    this.cards = this.cards.filter((card) => card.color !== color)
    this.selected = []
    this.renderSolved(color)

    if (this.solvedColors.length === this.puzzleValue.groups.length) {
      this.finish(true)
    } else {
      this.render()
    }
  }

  registerMistake(colors) {
    this.mistakes += 1
    this.renderMistakes()

    // "One away" — three of the four picked tiles share a color.
    const counts = {}
    colors.forEach((color) => { counts[color] = (counts[color] || 0) + 1 })
    const oneAway = Object.values(counts).some((n) => n === 3)

    if (this.mistakes >= this.maxMistakesValue) {
      this.selected = []
      this.finish(false)
      return
    }

    this.setStatus(oneAway ? "One away…" : "Not quite — try again")
    this.rejectSelection() // wiggle the picked tiles; they stay selected
  }

  // Wrong guess: the picked tiles do a quick wiggle (−3°↔3°) and STAY selected —
  // the player unpicks them (tap by tap, or Deselect all) themselves, so their
  // working memory of what they just tried isn't erased out from under them.
  rejectSelection() {
    if (this.reducedMotion) return
    const tiles = [...this.boardTarget.querySelectorAll(".m-card.is-selected")]
    tiles.forEach((tile) => {
      // composite:"add" layers the wiggle on top of the tile's lift transform.
      tile.animate(
        [
          { transform: "rotate(-3deg)" },
          { transform: "rotate(3deg)" },
          { transform: "rotate(-3deg)" },
          { transform: "rotate(3deg)" },
          { transform: "rotate(0deg)" }
        ],
        { duration: 280, easing: "ease-in-out", composite: "add" }
      )
    })
  }

  finish(won) {
    this.over = true
    this.element.classList.add("is-over") // hides the shuffle/deselect/submit row
    if (!won) {
      // Reveal the groups they never found so the answers are visible.
      Object.keys(this.groups)
        .filter((color) => !this.solvedColors.includes(color))
        .forEach((color) => this.renderSolved(color))
      this.cards = []
    }
    this.selected = []
    this.render()
    this.renderEndStamp(won)
    this.dispatch("finished", {
      detail: { won, mistakes: this.mistakes, guesses: this.guesses }
    })
    this.record(won)
  }

  // --- timing + funnel beacon -------------------------------------------

  // Start the clock on the first interaction and fire the game_started beacon
  // once. "Started" means the player actually began (first tile tap) — distinct
  // from merely opening the page — so a started-but-unfinished game is an abandon.
  markStarted() {
    if (this.startTime !== null) return
    // A resumed game picks its clock up where the save left off, and doesn't
    // re-beacon game_started — it's the same game, not a new start.
    this.startTime = performance.now() - this.resumedElapsed
    if (!this.resumed) this.recordStart()
  }

  // ms since the clock started; null if it never did (no interaction yet).
  elapsedMs() {
    return this.startTime === null ? null : Math.round(performance.now() - this.startTime)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  // Best-effort game_started beacon — a missed start never affects the game.
  // Marks the element `data-started` so a test can wait on the round-trip.
  async recordStart() {
    if (!this.hasEventsUrlValue || this.eventsUrlValue === "") return

    try {
      await fetch(this.eventsUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
        credentials: "same-origin"
      })
      this.element.dataset.started = "true"
    } catch {
      // Funnel stats are nice-to-have; a failed beacon shouldn't break the game.
    }
  }

  // Save the in-progress game after a guess (best-effort — a failed save never
  // breaks the game, it just won't resume). Marks the element
  // `data-progress-saved` with the guess count so a test can wait on the round-trip.
  async saveProgress() {
    if (!this.hasProgressUrlValue || this.progressUrlValue === "") return

    try {
      const response = await fetch(this.progressUrlValue, {
        method: "PUT",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
        credentials: "same-origin",
        body: JSON.stringify({
          progress: { guesses: this.guesses, elapsed_ms: this.elapsedMs() }
        })
      })
      if (response.ok) this.element.dataset.progressSaved = String(this.guesses.length)
    } catch {
      // Resume is nice-to-have; play on.
    }
  }

  // Persist the finished play for stats (best-effort — never block the game on
  // it). Marks the element `data-recorded` so a test can wait on the round-trip.
  async record(won) {
    if (!this.hasRecordUrlValue || this.recordUrlValue === "") return

    try {
      const response = await fetch(this.recordUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
        credentials: "same-origin",
        body: JSON.stringify({
          attempt: {
            solved: won,
            mistakes_count: this.mistakes,
            duration_ms: this.elapsedMs(),
            guesses: this.guesses
          }
        })
      })

      // The POST round-tripped — mark it done, then show whatever cube came back.
      this.element.dataset.recorded = "true"
      if (response.ok) {
        const data = await response.json().catch(() => ({}))
        this.renderAwards(data.awards)
        this.renderShare(data.cube, data.share)
        this.renderRating(data.rating)
      }
    } catch {
      // Stats are nice-to-have; a failed save shouldn't break the player's game.
    }
  }

  // The trophies + quip block (ADR-0011), rendered server-side from our own
  // partial — trusted markup, so inject it as-is above the shareable cube.
  renderAwards(html) {
    if (html) this.element.insertAdjacentHTML("beforeend", html)
  }

  // Post-play rating buttons (published puzzles only) — server-rendered partial;
  // its own Stimulus controller wires up once injected.
  renderRating(html) {
    if (html) this.element.insertAdjacentHTML("beforeend", html)
  }

  // The shareable cube + a copy-to-clipboard button, for bragging over text. The
  // grid shows the cube as palette-matched CSS blocks (mirrors the cube_grid
  // helper — the raw emoji live only in the copied share text); the copy writes
  // the full block (title + cube + link) the server built, falling back to the
  // cube if it didn't send one.
  renderShare(cube, shareText) {
    if (!cube) return
    const toCopy = shareText || cube

    const share = document.createElement("div")
    share.className = "m-game__share"

    const CELLS = { "🟨": "yellow", "🟩": "green", "🟦": "blue", "🟪": "purple" }
    const grid = document.createElement("p")
    grid.className = "m-cube"
    grid.setAttribute("aria-hidden", "true")
    cube.split("\n").forEach((line) => {
      const row = document.createElement("span")
      row.className = "m-cube__row"
      ;[...line].forEach((square) => {
        const cell = document.createElement("span")
        cell.className = `m-cube__cell m-cube__cell--${CELLS[square] || "blank"}`
        row.appendChild(cell)
      })
      grid.appendChild(row)
    })

    const copy = document.createElement("button")
    copy.type = "button"
    copy.className = "m-btn"
    copy.textContent = "Copy result"
    copy.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(toCopy)
        copy.textContent = "Copied!"
      } catch {
        copy.textContent = "Press ⌘/Ctrl-C to copy"
      }
    })

    share.append(grid, copy)
    this.element.appendChild(share)
  }

  // --- rendering --------------------------------------------------------

  render() {
    this.boardTarget.innerHTML = ""
    // Shrink the board's reserved min-height along with the grid (see .m-board).
    this.boardTarget.style.setProperty("--rows", Math.max(1, Math.ceil(this.cards.length / 4)))
    this.cards.forEach((card) => {
      const tile = document.createElement("button")
      tile.type = "button"
      tile.className = "m-card"
      tile.textContent = card.word
      tile.dataset.word = card.word // lets shuffle() map words → live elements
      tile.disabled = this.over
      // Shrink the font for tiles whose longest word won't fit at full size, so a
      // long unbreakable name wraps cleanly (or fits on one line) instead of
      // snapping off an orphan letter.
      tile.style.setProperty("--card-fit", cardFit(card.word))
      // Each tile leans a little differently (−3°…+3°) when it lifts.
      tile.style.setProperty("--tilt", `${(Math.random() * 6 - 3).toFixed(1)}deg`)
      if (this.selected.includes(card.word)) {
        tile.classList.add("is-selected")
        tile.setAttribute("aria-pressed", "true")
      }
      tile.addEventListener("click", (e) => this.toggle(card.word, e.currentTarget))
      this.boardTarget.appendChild(tile)
    })

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = this.over || this.selected.length !== 4
    }
  }

  renderSolved(color) {
    const group = this.groups[color]
    const row = document.createElement("div")
    row.className = `m-group m-group--${color} m-game__group`
    // textContent, not innerHTML — description/words are author-authored and
    // authoring is public, so interpolating them as HTML is a stored-XSS sink.
    const name = document.createElement("strong")
    name.className = "m-game__group-name"
    name.textContent = group.description
    const words = document.createElement("span")
    words.className = "m-game__group-words"
    words.textContent = group.words.join(", ")
    row.append(name, words)
    this.solvedTarget.appendChild(row)
  }

  // Four boxes, one per category color; a mistake puts an ✕ in the next box.
  renderMistakes() {
    if (!this.hasMistakesTarget) return
    this.mistakesTarget.innerHTML = ""
    GAME_COLORS.forEach((color, i) => {
      const box = document.createElement("span")
      box.className = `m-mistake m-mistake--${color}`
      if (i < this.mistakes) {
        box.classList.add("is-used")
        box.textContent = "✕"
      }
      this.mistakesTarget.appendChild(box)
    })
  }

  // A transient wrong-guess message: a toast that floats over the title/byline
  // area (.m-game__toast), then fades on its own. Also rides aria-live for SR.
  setStatus(text) {
    if (!this.hasToastTarget) return
    clearTimeout(this.statusTimer)
    this.toastTarget.textContent = text
    this.toastTarget.classList.add("is-visible")
    this.statusTimer = setTimeout(() => {
      this.toastTarget.classList.remove("is-visible")
    }, 1400)
  }

  // Slap a big tilted stamp on the board at game over — the payoff moment.
  renderEndStamp(won) {
    if (!this.hasStatusTarget) return
    // Cancelling the toast's fade timer would freeze a just-shown "one away"
    // toast over the header forever, so hide it here too.
    clearTimeout(this.statusTimer)
    if (this.hasToastTarget) this.toastTarget.classList.remove("is-visible")
    this.statusTarget.innerHTML = ""
    const stamp = document.createElement("span")
    stamp.className = won ? "m-stamp m-stamp--win" : "m-stamp m-stamp--lose"
    stamp.textContent = won ? "Solved it ↗" : "Out of guesses"
    this.statusTarget.appendChild(stamp)
    this.statusTarget.classList.add("is-visible") // persists — no auto-dismiss
  }

  shuffleCards() {
    for (let i = this.cards.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.cards[i], this.cards[j]] = [this.cards[j], this.cards[i]]
    }
  }

  // Honor the OS "reduce motion" preference — deselect/shuffle skip the
  // stagger + slide and just snap to the result.
  get reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
