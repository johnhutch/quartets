import { Controller } from "@hotwired/stimulus"

// Live "N left" counter for a length-capped field.
//   data-controller="charcount" data-charcount-max-value="200"
//   <textarea data-charcount-target="input" data-action="input->charcount#update">
//   <span data-charcount-target="count">
export default class extends Controller {
  static targets = ["input", "count"]
  static values = { max: Number }

  connect() { this.update() }

  update() {
    const left = this.maxValue - (this.inputTarget.value || "").length
    this.countTarget.textContent = `${left} left`
  }
}
