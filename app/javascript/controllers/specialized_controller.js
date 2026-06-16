import { Controller } from "@hotwired/stimulus"

// Wraps the "specialized" fieldset. The CSS :has reveal opens the tag box when the
// YES toggle is on; this controller guards turning it OFF — if there are tags, it
// confirms, slides them away, then lets the box itself slide closed.
//
//   data-controller="specialized" data-specialized-tags-outlet=".m-tags"
//   <input ... data-specialized-target="box" data-action="change->specialized#toggle">
export default class extends Controller {
  static targets = ["box"]
  static outlets = ["tags"]

  connect() {
    this.sync() // reconcile the class with the server-rendered checked state
  }

  toggle() {
    if (this.boxTarget.checked) return this.sync() // turning on — open the box
    if (!this.hasTagsOutlet || this.tagsOutlet.isEmpty()) return this.sync() // close now

    // Hold the box open while we ask + animate (reverting the user's uncheck).
    this.boxTarget.checked = true
    this.sync()
    if (!window.confirm("Remove all tags from this quartet?")) return

    // 1) slide the chips up, then 2) close the box.
    this.tagsOutlet.clearAnimated(() => {
      this.boxTarget.checked = false
      this.sync()
      this.boxTarget.dispatchEvent(new Event("input", { bubbles: true })) // autosave
    })
  }

  // Drive the reveal off a class, not :has(:checked) — the latter doesn't reliably
  // re-evaluate after a *programmatic* checked change (which is how we close it).
  sync() {
    this.element.classList.toggle("is-on", this.boxTarget.checked)
  }
}
