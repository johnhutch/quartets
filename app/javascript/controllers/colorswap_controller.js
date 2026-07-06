import { Controller } from "@hotwired/stimulus"

const COLOR_CLASS = /^m-group--/

// Swap this group block's color with another's (authoring form). Colors are an
// exchange, never a set — four groups, four colors, always one of each. Both
// fieldsets recolor IN PLACE: no live reordering, because on a phone the box
// you're editing would jump out from under you mid-thought. The easiest→hardest
// form order reasserts itself on the next load.
export default class extends Controller {
  static values = { color: String }
  static targets = ["name", "menu", "toggle", "field", "answer"]

  toggle() {
    const opening = this.menuTarget.hidden
    this.menuTarget.hidden = !opening
    this.toggleTarget.setAttribute("aria-expanded", String(opening))
    if (opening) this.markCurrent()
  }

  choose(event) {
    const color = event.params.color
    this.close()
    if (color === this.colorValue) return
    const partner = this.siblings().find((el) => el.dataset.colorswapColorValue === color)
    if (!partner) return

    this.constructor.paint(partner, this.colorValue)
    this.constructor.paint(this.element, color)
    // Hidden-field writes don't fire input events on their own — wake the autosave.
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  // --- internals ----------------------------------------------------------

  close() {
    this.menuTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
  }

  markCurrent() {
    this.menuTarget.querySelectorAll("button").forEach((button) => {
      button.disabled = button.dataset.colorswapColorParam === this.colorValue
    })
  }

  siblings() {
    const form = this.element.form || document
    return [...form.querySelectorAll('[data-controller~="colorswap"]')].filter((el) => el !== this.element)
  }

  // Recolor one fieldset: class, Stimulus value, legend label, hidden color
  // field, and the answers' accessible names. Static — it paints the partner's
  // DOM too, without reaching into another controller instance.
  static paint(el, color) {
    const title = color.charAt(0).toUpperCase() + color.slice(1)
    ;[...el.classList].forEach((c) => { if (COLOR_CLASS.test(c)) el.classList.remove(c) })
    el.classList.add(`m-group--${color}`)
    el.dataset.colorswapColorValue = color
    el.querySelector('[data-colorswap-target="name"]').textContent = title
    el.querySelector('[data-colorswap-target="field"]').value = color
    el.querySelectorAll('[data-colorswap-target="answer"]').forEach((input, i) => {
      input.setAttribute("aria-label", `${title} answer ${i + 1}`)
    })
  }
}
