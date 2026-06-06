import { Controller } from "@hotwired/stimulus"

// Auto-saves the authoring form in the background so the iOS back button can
// never eat work in progress. Debounced on input: the first save POSTs and
// creates the draft, then we flip the form to PATCH that record from there on.
//
//   data-controller="autosave"
//   data-autosave-debounce-value="1000"   (ms; tune on a phone)
//   data-autosave-target="status"         (optional save indicator)
export default class extends Controller {
  static targets = ["status"]
  static values = { debounce: { type: Number, default: 1000 } }

  connect() {
    this.timer = null
    this.saving = false
    this.dirty = false
    this.setStatus("idle")
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // Wire to the form's input/change events.
  schedule() {
    this.setStatus("pending")
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.debounceValue)
  }

  async save() {
    // Coalesce: if a save is already in flight, remember to run once more after.
    if (this.saving) {
      this.dirty = true
      return
    }

    this.saving = true
    this.dirty = false
    this.setStatus("saving")

    const form = this.element
    const body = new FormData(form)
    body.append("autosave", "1")

    try {
      const response = await fetch(form.action, {
        method: this.method,
        body,
        headers: { "X-CSRF-Token": this.csrfToken, Accept: "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error(`save failed: ${response.status}`)

      // First save just minted the record — switch to updating it in place so
      // the next keystroke PATCHes instead of creating a duplicate.
      if (response.status === 201) {
        const location = response.headers.get("Location")
        if (location) this.becomeEditable(location)
      }

      this.setStatus("saved")
    } catch (error) {
      this.setStatus("error")
    } finally {
      this.saving = false
      if (this.dirty) this.save() // changes landed mid-flight; flush them
    }
  }

  // Re-point a brand-new form at its persisted record: PATCH, edit URL, and a
  // matching browser URL so a reload or back-button lands on the saved draft.
  becomeEditable(url) {
    this.element.action = url
    this.methodField.value = "patch"
    window.history.replaceState({}, "", url)
  }

  get method() {
    return this.methodField.value.toUpperCase()
  }

  // Rails ships the real verb in a hidden _method field; default POST if absent.
  get methodField() {
    let field = this.element.querySelector('input[name="_method"]')
    if (!field) {
      field = document.createElement("input")
      field.type = "hidden"
      field.name = "_method"
      field.value = "post"
      this.element.appendChild(field)
    }
    return field
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  setStatus(state) {
    if (!this.hasStatusTarget) return
    this.statusTarget.dataset.state = state
    this.statusTarget.textContent = {
      idle: "",
      pending: "Saving…",
      saving: "Saving…",
      saved: "Saved",
      error: "Save failed — keep going, we'll retry"
    }[state]
  }
}
