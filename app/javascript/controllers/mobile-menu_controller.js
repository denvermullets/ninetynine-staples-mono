import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["menu"];

  toggle() {
    this.menuTarget.classList.toggle("hidden");
    this.menuTarget.classList.toggle("flex");
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden");
      this.menuTarget.classList.remove("flex");
    }
  }

  connect() {
    document.addEventListener("click", this.close.bind(this));
  }

  disconnect() {
    document.removeEventListener("click", this.close.bind(this));
  }
}
