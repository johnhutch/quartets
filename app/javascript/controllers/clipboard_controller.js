import { Controller } from "@hotwired/stimulus"

// Copy a string to the clipboard and flash a confirmation. Updates a `label`
// target if present (so an icon beside it survives), else the button text.
// Usage: data-controller="clipboard" data-clipboard-text-value="…"
//        <button data-action="clipboard#copy"><span data-clipboard-target="label">Share</span></button>
export default class extends Controller {
  static values = { text: String }
  static targets = ["label"]

  async copy() {
    const sink = this.hasLabelTarget ? this.labelTarget : this.element
    const original = sink.textContent
    try {
      await navigator.clipboard.writeText(this.textValue)
      sink.textContent = "Copied!"
    } catch {
      sink.textContent = "Press ⌘/Ctrl-C"
    }
    setTimeout(() => { sink.textContent = original }, 2000)
  }
}
