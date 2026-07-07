import { Controller } from "@hotwired/stimulus"

// The archive's filter form: flipping a checkbox submits right away (a plain
// GET — Turbo turns it into a visit, and nothing is persisted anywhere).
export default class extends Controller {
  apply() {
    this.element.requestSubmit()
  }
}
