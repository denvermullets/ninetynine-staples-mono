import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="partner-toggle"
export default class extends Controller {
  static targets = ["addButton", "container", "hiddenField"];

  show() {
    this.addButtonTarget.classList.add("hidden");
    this.containerTarget.classList.remove("hidden");
  }

  hide() {
    this.containerTarget.classList.add("hidden");
    this.addButtonTarget.classList.remove("hidden");

    // Clear the hidden field value when removing partner
    if (this.hasHiddenFieldTarget) {
      this.hiddenFieldTarget.value = "";
    }
  }
}
