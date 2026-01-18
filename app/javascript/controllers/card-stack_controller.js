import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="card-stack"
export default class extends Controller {
  static targets = ["card"];

  static values = {
    overlapPercent: { type: Number, default: 85 },
  };

  connect() {
    // Wait for images to load to get accurate card height
    this.cardTargets.forEach((card) => {
      const img = card.querySelector("img");
      if (img && !img.complete) {
        img.addEventListener("load", () => this.applyStackOffset(), { once: true });
      }
    });
    this.applyStackOffset();
  }

  applyStackOffset() {
    const firstCard = this.cardTargets[0];
    if (!firstCard) return;

    // Get the actual card height
    const cardHeight = firstCard.offsetHeight || 280;
    const overlapAmount = Math.floor(cardHeight * (this.overlapPercentValue / 100));

    this.cardTargets.forEach((card, index) => {
      card.style.transition = "margin-top 0.2s ease-out";
      if (index > 0) {
        card.style.marginTop = `-${overlapAmount}px`;
      }
      card.dataset.defaultMargin = index > 0 ? `-${overlapAmount}` : "0";
    });
  }

  expand(event) {
    const hoveredCard = event.currentTarget;
    const hoveredIndex = this.cardTargets.indexOf(hoveredCard);

    // Only push the card immediately below down to reveal the hovered card
    // Other cards stay stacked relative to each other
    const nextCard = this.cardTargets[hoveredIndex + 1];
    if (nextCard) {
      nextCard.style.marginTop = "0px";
    }
  }

  collapse() {
    // Reset all cards to their default stacked position
    this.cardTargets.forEach((card) => {
      const defaultMargin = card.dataset.defaultMargin || "0";
      card.style.marginTop = `${defaultMargin}px`;
    });
  }
}
