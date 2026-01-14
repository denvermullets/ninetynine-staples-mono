import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="card-stack"
export default class extends Controller {
  static targets = ["card", "hoverPreview"];

  static values = {
    stackOffset: { type: Number, default: 80 },
  };

  connect() {
    this.applyStackOffset();
  }

  applyStackOffset() {
    this.cardTargets.forEach((card, index) => {
      if (index > 0) {
        card.style.marginTop = `-${this.stackOffsetValue}px`;
      }
    });
  }

  showPreview(event) {
    const card = event.currentTarget;
    const imageUrl = card.dataset.imageLarge;

    if (this.hasHoverPreviewTarget && imageUrl) {
      this.hoverPreviewTarget.src = imageUrl;
      this.hoverPreviewTarget.classList.remove("hidden");

      // Position to the right of the stack
      const rect = this.element.getBoundingClientRect();
      const previewWidth = 256; // w-64 = 16rem = 256px
      const viewportWidth = window.innerWidth;

      // Check if there's room on the right
      if (rect.right + previewWidth + 20 < viewportWidth) {
        this.hoverPreviewTarget.style.left = `${rect.right + 10}px`;
      } else {
        // Place on the left
        this.hoverPreviewTarget.style.left = `${rect.left - previewWidth - 10}px`;
      }

      this.hoverPreviewTarget.style.top = `${Math.max(10, rect.top)}px`;
    }
  }

  hidePreview() {
    if (this.hasHoverPreviewTarget) {
      this.hoverPreviewTarget.classList.add("hidden");
    }
  }
}
