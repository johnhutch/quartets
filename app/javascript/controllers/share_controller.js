import { Controller } from "@hotwired/stimulus"

// Share a URL. On devices with a native share sheet (iOS/Android) it opens the
// sheet — a link composed there unfurls into a rich preview in Messages, where
// a pasted one often doesn't. Everywhere else it falls back to a clipboard copy
// (same UX as clipboard_controller). Only the bare URL is shared: any extra
// text in the payload would demote the message to plain text and kill the card.
// Usage: data-controller="share" data-share-url-value="…"
//        <button data-action="share#share"><span data-share-target="label">Share</span></button>
export default class extends Controller {
  static values = { url: String }
  static targets = ["label"]

  async share() {
    const data = { url: this.urlValue }
    if (navigator.share && (!navigator.canShare || navigator.canShare(data))) {
      try {
        await navigator.share(data)
        return
      } catch (error) {
        if (error.name === "AbortError") return // user closed the sheet — done
        // anything else (sheet unavailable mid-flight) falls through to copy
      }
    }
    this.copy()
  }

  async copy() {
    const sink = this.hasLabelTarget ? this.labelTarget : this.element
    const original = sink.textContent
    try {
      await navigator.clipboard.writeText(this.urlValue)
      sink.textContent = "Copied!"
    } catch {
      sink.textContent = "Press ⌘/Ctrl-C"
    }
    setTimeout(() => { sink.textContent = original }, 2000)
  }
}
