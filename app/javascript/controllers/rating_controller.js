import { Controller } from "@hotwired/stimulus"

// Post-play rating buttons. Each tap PATCHes one field (quality or difficulty)
// onto the viewer's attempt and lights the picked option, dimming its row-mates.
// Best-effort like the attempt POST itself — a failed save just leaves the
// buttons unlit.
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
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ [field]: choice }),
        credentials: "same-origin"
      })
    } catch {
      return // network hiccup — best-effort, leave the buttons unlit
    }
    if (!response.ok) return

    this.element.querySelectorAll(`[data-rating-field-param="${field}"]`).forEach((option) => {
      option.classList.toggle("is-on", option === button)
    })
  }
}
