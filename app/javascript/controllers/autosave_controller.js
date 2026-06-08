import { Controller } from "@hotwired/stimulus"

// Debounced background save for the puzzle form. This is the reason the app
// exists: every edit quietly PATCHes the draft, so a stray iPhone back button
// never eats your work. No save button to remember, no "did that persist?"
//
// Wire it on a persisted form:
//   data-controller="autosave"
//   data-action="input->autosave#schedule change->autosave#schedule"
//   data-autosave-target="status"   (an element to show Saving…/Saved)
export default class extends Controller {
  static targets = ["status"]
  static values = { delay: { type: Number, default: 800 } }

  disconnect() {
    clearTimeout(this.timeout)
  }

  // Every keystroke resets the clock; we only save once typing pauses.
  schedule() {
    clearTimeout(this.timeout)
    this.setStatus("Editing…")
    this.timeout = setTimeout(() => this.save(), this.delayValue)
  }

  async save() {
    const form = this.element
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    this.setStatus("Saving…")
    try {
      // POST + the form's hidden _method=patch makes Rails treat this as PATCH.
      const response = await fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        headers: { Accept: "application/json", "X-CSRF-Token": token },
      })
      this.setStatus(response.ok ? "Saved ✓" : "Couldn't save — keep this tab open")
    } catch {
      this.setStatus("Offline — will retry on your next change")
    }
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
