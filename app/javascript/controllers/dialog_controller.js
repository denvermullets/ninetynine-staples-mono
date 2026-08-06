import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dialog"
//
// For a <dialog> that is already on the page and opens on click. The modal controller
// calls showModal() on connect instead, which suits modals loaded into a turbo frame.
export default class extends Controller {
  static targets = ["dialog"];

  open() {
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
