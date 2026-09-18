import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="toast"
// A toast that asks the user something sets data-toast-persist-value="true" and stays until dismissed.
export default class extends Controller {
  static targets = ["message"];
  static values = { persist: Boolean };

  connect() {
    if (this.persistValue) return;

    // dismiss after 5s
    this.timeout = setTimeout(() => this.dismiss(), 5000);
  }

  disconnect() {
    clearTimeout(this.timeout);
  }

  dismiss() {
    // remove from DOM after fade-out
    this.element.classList.add("opacity-0", "transition-opacity", "duration-500");
    setTimeout(() => this.element.remove(), 500);
  }
}
