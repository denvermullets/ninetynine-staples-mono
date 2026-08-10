import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dismissable"
// Escape closes a hand-rolled overlay (a `hidden`-toggled div, not a native
// <dialog> - those get Escape for free from showModal()).
export default class extends Controller {
  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    document.addEventListener("keydown", this.boundHandleKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown);
  }

  handleKeydown(event) {
    if (event.key !== "Escape") return;
    if (this.element.classList.contains("hidden")) return;

    this.element.classList.add("hidden");
  }
}
