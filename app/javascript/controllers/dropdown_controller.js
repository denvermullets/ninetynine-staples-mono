import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button", "filter", "item"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")

    // a set picker can hold a few hundred entries, so opening it puts the cursor in the box
    if (!this.menuTarget.classList.contains("hidden") && this.hasFilterTarget) {
      this.filterTarget.focus()
    }
  }

  // Optional: menus without a filter target never call this, so the collection picker is untouched
  filter() {
    const query = this.filterTarget.value.trim().toLowerCase()

    this.itemTargets.forEach((item) => {
      item.classList.toggle("hidden", query !== "" && !item.dataset.search.includes(query))
    })
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  connect() {
    document.addEventListener("click", this.close.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.close.bind(this))
  }
}
