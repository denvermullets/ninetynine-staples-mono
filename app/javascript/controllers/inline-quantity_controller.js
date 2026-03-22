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

  viewStateParams() {
    const deckBuilder = document.querySelector("[data-controller~='deck-builder']");
    if (!deckBuilder) return "";

    const params = new URLSearchParams();
    const grouping = deckBuilder.dataset.deckBuilderGroupingValue;
    const sortBy = deckBuilder.dataset.deckBuilderSortByValue;
    const viewMode = deckBuilder.dataset.deckBuilderViewModeValue;

    if (grouping) params.set("grouping", grouping);
    if (sortBy) params.set("sort_by", sortBy);
    if (viewMode) params.set("view_mode", viewMode);

    const str = params.toString();
    return str ? `&${str}` : "";
  }

  async save(event) {
    if (event) {
      event.preventDefault();
    }

    const quantity = parseInt(this.inputTarget.value) || 0;
    const foilQuantity = this.hasFoilInputTarget
      ? parseInt(this.foilInputTarget.value) || 0
      : 0;

    const formData = new FormData();
    formData.append("quantity", quantity);
    formData.append("foil_quantity", foilQuantity);

    try {
      const response = await fetch(
        `/deck-builder/${this.deckIdValue}/update_quantity?card_id=${this.cardIdValue}${this.viewStateParams()}`,
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
