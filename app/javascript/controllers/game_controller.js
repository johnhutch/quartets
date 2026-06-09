import { Controller } from "@hotwired/stimulus"

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
  static targets = ["board", "solved", "status", "mistakes", "submit"]
  static values = {
    puzzle: Object,
    maxMistakes: { type: Number, default: 4 }
  }

  connect() {
    this.groups = {}        // color -> { description, words: [...] }
    this.colorOf = {}       // word  -> color
    this.cards = []         // { word, color } for the tiles still in play
    this.selected = []      // selected words (max 4)
    this.solvedColors = []  // colors already found
    this.mistakes = 0
    this.guesses = []       // [{ words: [...], correct: bool }]
    this.over = false

    this.puzzleValue.groups.forEach((group) => {
      this.groups[group.color] = { description: group.description, words: group.words }
      group.words.forEach((word) => {
        this.colorOf[word] = group.color
        this.cards.push({ word, color: group.color })
      })
    })

    this.shuffleCards()
    this.render()
    this.renderMistakes()
  }

  // --- player actions ---------------------------------------------------

  shuffle() {
    if (this.over) return
    this.shuffleCards()
    this.render()
  }

  deselect() {
    if (this.over) return
    this.selected = []
    this.render()
  }

  submit() {
    if (this.over || this.selected.length !== 4) return

    const colors = this.selected.map((word) => this.colorOf[word])
    const correct = colors.every((color) => color === colors[0])
    this.guesses.push({ words: [...this.selected], correct })

    if (correct) {
      this.lockGroup(colors[0])
    } else {
      this.registerMistake(colors)
    }
  }

  // --- internals --------------------------------------------------------

  toggle(word) {
    if (this.over) return
    const at = this.selected.indexOf(word)
    if (at >= 0) {
      this.selected.splice(at, 1)
    } else if (this.selected.length < 4) {
      this.selected.push(word)
    }
    this.render()
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

    this.selected = []

    if (this.mistakes >= this.maxMistakesValue) {
      this.finish(false)
    } else {
      this.setStatus(oneAway ? "One away…" : "Not quite — try again")
      this.render()
    }
  }

  finish(won) {
    this.over = true
    if (!won) {
      // Reveal the groups they never found so the answers are visible.
      Object.keys(this.groups)
        .filter((color) => !this.solvedColors.includes(color))
        .forEach((color) => this.renderSolved(color))
      this.cards = []
    }
    this.selected = []
    this.render()
    this.setStatus(won ? "Solved it! 🎉" : "Out of guesses — the answers are above")
    this.dispatch("finished", {
      detail: { won, mistakes: this.mistakes, guesses: this.guesses }
    })
  }

  // --- rendering --------------------------------------------------------

  render() {
    this.boardTarget.innerHTML = ""
    this.cards.forEach((card) => {
      const tile = document.createElement("button")
      tile.type = "button"
      tile.className = "m-card"
      tile.textContent = card.word
      tile.disabled = this.over
      if (this.selected.includes(card.word)) {
        tile.classList.add("is-selected")
        tile.setAttribute("aria-pressed", "true")
      }
      tile.addEventListener("click", () => this.toggle(card.word))
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
    row.innerHTML =
      `<strong class="m-game__group-name">${group.description}</strong>` +
      `<span class="m-game__group-words">${group.words.join(", ")}</span>`
    this.solvedTarget.appendChild(row)
  }

  renderMistakes() {
    if (!this.hasMistakesTarget) return
    const left = this.maxMistakesValue - this.mistakes
    this.mistakesTarget.textContent =
      `Mistakes remaining: ${"●".repeat(left)}${"○".repeat(this.mistakes)}`
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  shuffleCards() {
    for (let i = this.cards.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.cards[i], this.cards[j]] = [this.cards[j], this.cards[i]]
    }
  }
}
