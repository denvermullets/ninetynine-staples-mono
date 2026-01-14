import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="inline-quantity"
export default class extends Controller {
  static targets = ["display", "input", "foilInput"];
  static values = {
    deckId: Number,
    cardId: Number,
  };

  edit(event) {
    event.preventDefault();
    event.stopPropagation();
    this.displayTarget.classList.add("hidden");
    this.inputTarget.classList.remove("hidden");
    this.inputTarget.focus();
    this.inputTarget.select();
  }

  cancel() {
    this.inputTarget.classList.add("hidden");
    this.displayTarget.classList.remove("hidden");
  }

  async save(event) {
    if (event) {
      event.preventDefault();
    }

    const quantity = parseInt(this.inputTarget.value) || 0;
    const foilQuantity = this.hasFoilInputTarget
      ? parseInt(this.foilInputTarget.value) || 0
      : 0;

    // Don't save if both are zero
    if (quantity === 0 && foilQuantity === 0) {
      this.cancel();
      return;
    }

    const formData = new FormData();
    formData.append("quantity", quantity);
    formData.append("foil_quantity", foilQuantity);

    try {
      const response = await fetch(
        `/deck-builder/${this.deckIdValue}/update_quantity?card_id=${this.cardIdValue}`,
        {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
              .content,
            Accept: "text/vnd.turbo-stream.html",
          },
          body: formData,
        }
      );

      const html = await response.text();
      Turbo.renderStreamMessage(html);
    } catch (error) {
      console.error("Failed to update quantity:", error);
    }

    this.cancel();
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.cancel();
    } else if (event.key === "Enter") {
      this.save(event);
    }
  }
}
