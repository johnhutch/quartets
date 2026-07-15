import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Post-play rating buttons. Each tap PATCHes one field (quality or difficulty)
// onto the viewer's attempt and lights the picked option, dimming its row-mates.
// The server answers with a turbo stream that swaps the header metabox, so the
// vote shows up in the tally without a reload. Best-effort like the attempt
// POST itself — a failed save just leaves the buttons unlit.
export default class extends Controller {
  static values = { url: String }

  async rate(event) {
    const { field, choice } = event.params
    const button = event.currentTarget
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    let response
    try {
      response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ [field]: choice }),
        credentials: "same-origin"
      })
    } catch {
      return // network hiccup — best-effort, leave the buttons unlit
    }
    if (!response.ok) return

    Turbo.renderStreamMessage(await response.text())

    this.element.querySelectorAll(`[data-rating-field-param="${field}"]`).forEach((option) => {
      option.classList.toggle("is-on", option === button)
    })
  }
}
