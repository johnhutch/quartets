import { Controller } from "@hotwired/stimulus"

// An in-box × that empties its text input (authoring form). The wrapper's
// input-event action keeps the button's visibility honest — it only shows
// while there's something to clear. Clearing refocuses the box and fires a
// real input event so autosave (and any other listener) hears about it.
export default class extends Controller {
  connect() {
    this.input = this.element.querySelector("input, textarea")
    this.button = this.element.querySelector("button")
    this.refresh()
  }

  refresh() {
    this.button.hidden = this.input.value === ""
  }

  clear() {
    this.input.value = ""
    this.input.focus()
    this.input.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
