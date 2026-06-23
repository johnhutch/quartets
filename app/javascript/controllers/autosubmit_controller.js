import { Controller } from "@hotwired/stimulus"

// Submit the form the moment a control changes — for filter toggles that should
// apply without a separate "Apply" button.
//   data-controller="autosubmit"
//   <input ... data-action="change->autosubmit#submit">
export default class extends Controller {
  submit() { this.element.requestSubmit() }
}
