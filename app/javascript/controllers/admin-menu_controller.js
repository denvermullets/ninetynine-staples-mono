// Connects to data-controller="admin"
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["menu"];

  toggle() {
    this.menuTarget.classList.toggle("hidden");
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden");
    }
  }

  connect() {
    document.addEventListener("click", this.close.bind(this));
  }

  disconnect() {
    document.removeEventListener("click", this.close.bind(this));
  }
}
