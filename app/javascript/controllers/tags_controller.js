import { Controller } from "@hotwired/stimulus"

// Creatable tag combobox. Type to search existing tags (via suggestUrl); pick a
// match to add it, or pick "Create new tag: …" to mint a new one. Selected tags
// render as chips with hidden `puzzle[tag_names][]` inputs — the server
// normalizes + find-or-creates on save. The normalize() here mirrors Tag.normalize
// so the create-label preview matches what'll actually be stored.
//
//   data-controller="tags" data-tags-suggest-url-value="/tags"
export default class extends Controller {
  static targets = ["input", "menu", "chips"]
  static values = { suggestUrl: String }

  connect() {
    this.selected = new Set(this.chipNames())
    this.items = []
    this.active = -1
    this.seq = 0
  }

  chipNames() {
    return [...this.chipsTarget.querySelectorAll('input[type="hidden"]')]
      .map((i) => i.value)
      .filter(Boolean)
  }

  normalize(raw) {
    return (raw || "").toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  }

  // Debounced; wired to input + focus.
  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.runSearch(), 120)
  }

  async runSearch() {
    const slug = this.normalize(this.inputTarget.value)
    if (!slug) return this.close()

    const seq = ++this.seq
    let matches = []
    try {
      const res = await fetch(`${this.suggestUrlValue}?q=${encodeURIComponent(this.inputTarget.value)}`,
        { headers: { Accept: "application/json" } })
      if (res.ok) matches = await res.json()
    } catch (_) { /* offline/failed — fall back to create-only */ }
    if (seq !== this.seq) return // superseded by a newer keystroke

    matches = matches.filter((n) => !this.selected.has(n))
    const items = matches.map((name) => ({ name, create: false }))
    // Offer "create" unless the exact typed slug already exists in matches or is chosen.
    if (!this.selected.has(slug) && !matches.includes(slug)) items.push({ name: slug, create: true })
    this.render(items)
  }

  render(items) {
    this.items = items
    this.active = -1
    if (items.length === 0) return this.close()

    this.menuTarget.innerHTML = ""
    items.forEach((item, i) => {
      const li = document.createElement("li")
      li.className = "m-tags__option"
      li.setAttribute("role", "option")
      li.textContent = item.create ? `Create new tag: ${item.name}` : item.name
      // mousedown (not click) so the input doesn't blur and swallow the pick.
      li.addEventListener("mousedown", (e) => { e.preventDefault(); this.choose(i) })
      this.menuTarget.appendChild(li)
    })
    this.open()
  }

  keydown(event) {
    if (this.menuTarget.hidden && event.key !== "Enter" && event.key !== "Backspace") return
    switch (event.key) {
      case "ArrowDown": event.preventDefault(); this.move(1); break
      case "ArrowUp": event.preventDefault(); this.move(-1); break
      case "Escape": this.close(); break
      case "Backspace": if (this.inputTarget.value === "") this.removeLast(); break
      case "Enter":
        event.preventDefault()
        if (this.active >= 0) this.choose(this.active)
        else { const slug = this.normalize(this.inputTarget.value); if (slug) { this.add(slug); this.afterAdd() } }
        break
    }
  }

  move(delta) {
    const n = this.items.length
    if (n === 0) return
    this.active = (this.active + delta + n) % n
    Array.from(this.menuTarget.children).forEach((li, i) => li.classList.toggle("is-active", i === this.active))
  }

  choose(i) {
    const item = this.items[i]
    if (item) { this.add(item.name); this.afterAdd() }
  }

  afterAdd() {
    this.inputTarget.value = ""
    this.close()
    this.inputTarget.focus()
  }

  add(name) {
    if (!name || this.selected.has(name)) return
    this.selected.add(name)

    const li = document.createElement("li")
    li.className = "m-tags__chip"
    const span = document.createElement("span")
    span.textContent = name
    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "m-tags__remove"
    btn.textContent = "×"
    btn.setAttribute("aria-label", `Remove ${name}`)
    btn.dataset.action = "tags#remove"
    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "puzzle[tag_names][]"
    hidden.value = name
    li.append(span, btn, hidden)
    this.chipsTarget.appendChild(li)
    this.notifyChange()
  }

  remove(event) {
    const chip = event.target.closest(".m-tags__chip")
    if (!chip) return
    this.selected.delete(chip.querySelector('input[type="hidden"]').value)
    chip.remove()
    this.notifyChange()
  }

  removeLast() {
    const chips = this.chipsTarget.querySelectorAll(".m-tags__chip")
    const last = chips[chips.length - 1]
    if (!last) return
    this.selected.delete(last.querySelector('input[type="hidden"]').value)
    last.remove()
    this.notifyChange()
  }

  // Chips are added/removed in JS, which fires no native input/change event — so
  // tell the form a change happened, or the autosave controller never sees the
  // tag edit and it's lost on the next navigation.
  notifyChange() {
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  open() { this.menuTarget.hidden = false; this.inputTarget.setAttribute("aria-expanded", "true") }
  close() { this.menuTarget.hidden = true; this.inputTarget.setAttribute("aria-expanded", "false"); this.items = []; this.active = -1 }
}
