import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="toast"
export default class extends Controller {
  static targets = ["message"];

  connect() {
    // dismiss after 3s
    this.timeout = setTimeout(() => this.dismiss(), 3000);
  }

  dismiss() {
    // remove from DOM after fade-out
    this.element.classList.add("opacity-0", "transition-opacity", "duration-500");
    setTimeout(() => this.element.remove(), 500);
  }
}
