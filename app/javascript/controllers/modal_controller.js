import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["content", "regularInput", "foilInput"];

  connect() {
    // Auto-open the dialog when it connects
    this.element.showModal();
  }

  close() {
    this.element.close();
  }

  closeOnBackdrop(event) {
    // Only close if clicking the backdrop (dialog element itself, not content)
    if (event.target === this.element) {
      this.close();
    }
  }

  increment(event) {
    event.preventDefault();
    if (this.hasRegularInputTarget) {
      const input = this.regularInputTarget;
      const max = parseInt(input.max) || 999;
      const current = parseInt(input.value) || 0;
      if (current < max) {
        input.value = current + 1;
      }
    }
  }

  decrement(event) {
    event.preventDefault();
    if (this.hasRegularInputTarget) {
      const input = this.regularInputTarget;
      const current = parseInt(input.value) || 0;
      if (current > 0) {
        input.value = current - 1;
      }
    }
  }

  incrementFoil(event) {
    event.preventDefault();
    if (this.hasFoilInputTarget) {
      const input = this.foilInputTarget;
      const max = parseInt(input.max) || 999;
      const current = parseInt(input.value) || 0;
      if (current < max) {
        input.value = current + 1;
      }
    }
  }

  decrementFoil(event) {
    event.preventDefault();
    if (this.hasFoilInputTarget) {
      const input = this.foilInputTarget;
      const current = parseInt(input.value) || 0;
      if (current > 0) {
        input.value = current - 1;
      }
    }
  }
}
