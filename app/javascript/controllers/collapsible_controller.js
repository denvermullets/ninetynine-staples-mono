import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { expanded: { type: Boolean, default: true } }

  connect() {
    this.updateState()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.updateState()
  }

  updateState() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.expandedValue)
    }
    if (this.hasIconTarget) {
      this.iconTarget.style.transform = this.expandedValue ? "rotate(0deg)" : "rotate(-90deg)"
    }
  }
}
