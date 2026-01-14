import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="alert-modal"
// Usage: dispatch "alert:show" event with detail: { title: "...", message: "..." }
export default class extends Controller {
  static targets = ["dialog", "title", "message"];

  connect() {
    // Listen for alert:show events on window
    this.boundShow = this.show.bind(this);
    window.addEventListener("alert:show", this.boundShow);
  }

  disconnect() {
    window.removeEventListener("alert:show", this.boundShow);
  }

  show(event) {
    const { title, message } = event.detail;
    this.titleTarget.textContent = title || "Alert";
    this.messageTarget.textContent = message;
    this.dialogTarget.showModal();
  }

  close() {
    this.dialogTarget.close();
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) {
      this.close();
    }
  }
}
