import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="add-card"
export default class extends Controller {
  static targets = [
    "sourceSelect",
    "quantityInput",
    "foilQuantityInput",
    "addOwnedButton",
    "addPlannedButton",
    "cardTypeSelect",
  ];

  static values = {
    deckId: Number,
    cardId: Number,
    collectionId: Number,
  };

  connect() {
    this.updateAvailability();
  }

  updateAvailability() {
    if (!this.hasSourceSelectTarget) return;

    const option = this.sourceSelectTarget.selectedOptions[0];
    if (!option) return;

    const maxQty = parseInt(option.dataset.maxQuantity) || 0;
    const maxFoil = parseInt(option.dataset.maxFoilQuantity) || 0;

    if (this.hasQuantityInputTarget) {
      this.quantityInputTarget.max = maxQty;
      if (parseInt(this.quantityInputTarget.value) > maxQty) {
        this.quantityInputTarget.value = maxQty;
      }
    }

    if (this.hasFoilQuantityInputTarget) {
      this.foilQuantityInputTarget.max = maxFoil;
      if (parseInt(this.foilQuantityInputTarget.value) > maxFoil) {
        this.foilQuantityInputTarget.value = maxFoil;
      }
    }
  }

  incrementQuantity() {
    const input = this.quantityInputTarget;
    const max = parseInt(input.max) || 99;
    const current = parseInt(input.value) || 0;
    if (current < max) {
      input.value = current + 1;
    }
  }

  decrementQuantity() {
    const input = this.quantityInputTarget;
    const current = parseInt(input.value) || 0;
    if (current > 0) {
      input.value = current - 1;
    }
  }

  incrementFoilQuantity() {
    const input = this.foilQuantityInputTarget;
    const max = parseInt(input.max) || 99;
    const current = parseInt(input.value) || 0;
    if (current < max) {
      input.value = current + 1;
    }
  }

  decrementFoilQuantity() {
    const input = this.foilQuantityInputTarget;
    const current = parseInt(input.value) || 0;
    if (current > 0) {
      input.value = current - 1;
    }
  }

  async addOwned(event) {
    event.preventDefault();

    // Use collectionId value if available (new owned partial), otherwise use sourceSelect
    let sourceId;
    if (this.hasCollectionIdValue && this.collectionIdValue) {
      sourceId = this.collectionIdValue;
    } else if (this.hasSourceSelectTarget) {
      sourceId = this.sourceSelectTarget.value;
    }

    if (!sourceId) {
      this.showAlert("Selection Required", "Please select a collection");
      return;
    }

    await this.submitAdd(sourceId);
  }

  async addPlanned(event) {
    event.preventDefault();
    await this.submitAdd(null);
  }

  async addNew(event) {
    event.preventDefault();

    const cardType = this.hasCardTypeSelectTarget
      ? this.cardTypeSelectTarget.value
      : "regular";

    const quantity = parseInt(this.quantityInputTarget.value) || 1;

    const formData = new FormData();
    formData.append("magic_card_id", this.cardIdValue);
    formData.append("card_type", cardType);
    formData.append("quantity", quantity);

    try {
      const response = await fetch(
        `/deck-builder/${this.deckIdValue}/add_new_card`,
        {
          method: "POST",
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

      // Reset the form
      this.quantityInputTarget.value = 1;

      // Dispatch event to clear search results
      window.dispatchEvent(new CustomEvent("deck:card-added"));
    } catch (error) {
      console.error("Failed to add card:", error);
    }
  }

  async submitAdd(sourceCollectionId) {
    const quantity = parseInt(this.quantityInputTarget.value) || 0;
    const foilQuantity = this.hasFoilQuantityInputTarget
      ? parseInt(this.foilQuantityInputTarget.value) || 0
      : 0;

    if (quantity === 0 && foilQuantity === 0) {
      this.showAlert("Quantity Required", "Please enter a quantity");
      return;
    }

    const formData = new FormData();
    formData.append("magic_card_id", this.cardIdValue);
    formData.append("quantity", quantity);
    formData.append("foil_quantity", foilQuantity);
    if (sourceCollectionId) {
      formData.append("source_collection_id", sourceCollectionId);
    }

    try {
      const response = await fetch(`/deck-builder/${this.deckIdValue}/add_card`, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          Accept: "text/vnd.turbo-stream.html",
        },
        body: formData,
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);

      // Reset the form
      this.quantityInputTarget.value = 1;
      if (this.hasFoilQuantityInputTarget) {
        this.foilQuantityInputTarget.value = 0;
      }

      // Dispatch event to clear search results
      window.dispatchEvent(new CustomEvent("deck:card-added"));
    } catch (error) {
      console.error("Failed to add card:", error);
    }
  }

  showAlert(title, message) {
    window.dispatchEvent(
      new CustomEvent("alert:show", {
        detail: { title, message },
      })
    );
  }
}
