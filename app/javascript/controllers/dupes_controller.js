import { Controller } from "@hotwired/stimulus"

// Flags repeated answers in the authoring form as they're typed. The board keys
// its tiles by word text (see game_controller), so the same answer twice renders
// an unwinnable puzzle — Puzzle#no_duplicate_answers refuses to publish one.
// The draft still auto-saves either way (losing work beats a tidy draft); this
// is the live warning that stops the author finding out at publish time.
//
//   data-controller="dupes"                    (on the form)
//   data-action="input->dupes#scan autosave:blocked->dupes#reveal"
//   data-dupes-target="summary"                (top-of-form complaint)
//   data-dupes-target="blocked"                (the same, next to Publish)
//   data-dupes-target="tooltip"                (Publish's guard tooltip)
export default class extends Controller {
  static targets = ["summary", "blocked", "tooltip"]

  connect() {
    this.dupes = []
    // Remember the tooltip's own reason so we can hand it back when the dupes go.
    this.incompleteReason = this.hasTooltipTarget ? this.tooltipTarget.textContent : null
    this.scan()
  }

  // Repaint from the current field values. Cheap enough to run on every
  // keystroke: sixteen inputs and a tally.
  scan() {
    const inputs = this.answerInputs
    const counts = new Map()

    inputs.forEach((input) => {
      const word = this.normalize(input.value)
      if (word) counts.set(word, (counts.get(word) || 0) + 1)
    })

    this.dupes = [...counts].filter(([, count]) => count > 1).map(([word]) => word)

    // The offending boxes go red. autosave#publishable reads these back off the
    // DOM, so the flags are the single source of truth — no state to keep in sync.
    inputs.forEach((input) => {
      input.classList.toggle("is-dupe", this.dupes.includes(this.normalize(input.value)))
    })

    this.render()
    this.dispatch("changed") // → autosave#refresh greys Publish
  }

  // The author clicked Publish and autosave's guard stopped it. Say why right
  // there — on a phone the summary at the top is long gone.
  reveal() {
    if (this.hasBlockedTarget) this.blockedTarget.hidden = this.dupes.length === 0
  }

  render() {
    const listed = this.dupes.join(", ")

    if (this.hasSummaryTarget) {
      this.summaryTarget.hidden = this.dupes.length === 0
      this.summaryTarget.textContent = this.dupes.length
        ? `Same answer more than once: ${listed}. Sixteen answers, sixteen different words — the board can't tell two identical tiles apart.`
        : ""
    }

    if (this.hasBlockedTarget) {
      this.blockedTarget.textContent = this.dupes.length ? `Can't publish yet — you've used the same answer twice: ${listed}.` : ""
      if (!this.dupes.length) this.blockedTarget.hidden = true
    }

    if (this.hasTooltipTarget) {
      this.tooltipTarget.textContent = this.dupes.length
        ? `Two of your answers are the same (${listed}). Fix that before publishing.`
        : this.incompleteReason
    }
  }

  get answerInputs() {
    return [...this.element.querySelectorAll('input[name$="[words][]"]')]
  }

  // Mirrors Puzzle.normalize_answer — case and stray spaces don't make two
  // answers different.
  normalize(value) {
    return value.trim().toLowerCase()
  }
}
