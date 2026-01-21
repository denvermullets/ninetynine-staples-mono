import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="card-hover"
// Shows a large card image when hovering over a card thumbnail
export default class extends Controller {
  static values = {
    image: String,
    name: String,
  };

  connect() {
    this.previewElement = null;
  }

  disconnect() {
    this.hidePreview();
  }

  show(event) {
    if (!this.imageValue) return;

    // Create preview element if it doesn't exist
    if (!this.previewElement) {
      this.previewElement = document.createElement("div");
      this.previewElement.className =
        "fixed z-[10000] pointer-events-none transition-opacity duration-150";
      this.previewElement.innerHTML = `
        <img src="${this.imageValue}"
             alt="${this.nameValue || "Card preview"}"
             class="w-80 rounded-xl shadow-2xl shadow-black/50 border border-highlight" />
      `;
      document.body.appendChild(this.previewElement);
    }

    this.updatePosition(event);
    this.previewElement.style.opacity = "1";
  }

  hide() {
    if (this.previewElement) {
      this.previewElement.style.opacity = "0";
      setTimeout(() => {
        if (this.previewElement) {
          this.previewElement.remove();
          this.previewElement = null;
        }
      }, 150);
    }
  }

  move(event) {
    this.updatePosition(event);
  }

  updatePosition(event) {
    if (!this.previewElement) return;

    const padding = 16;
    const previewWidth = 320; // w-80 = 20rem = 320px
    const previewHeight = 448; // approximate height of card

    let x = event.clientX + padding;
    let y = event.clientY - previewHeight / 2;

    // Keep preview on screen horizontally
    if (x + previewWidth > window.innerWidth) {
      x = event.clientX - previewWidth - padding;
    }

    // Keep preview on screen vertically
    if (y < padding) {
      y = padding;
    } else if (y + previewHeight > window.innerHeight - padding) {
      y = window.innerHeight - previewHeight - padding;
    }

    this.previewElement.style.left = `${x}px`;
    this.previewElement.style.top = `${y}px`;
  }

  hidePreview() {
    if (this.previewElement) {
      this.previewElement.remove();
      this.previewElement = null;
    }
  }
}
