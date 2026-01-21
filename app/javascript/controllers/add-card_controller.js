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
    cardType: String,
  };

  connect() {
    this.updateAvailability();
    this.updateMaxQuantity();
    this.handlePrintingSelected = this.handlePrintingSelected.bind(this);
    window.addEventListener("printing:selected", this.handlePrintingSelected);
  }

  disconnect() {
    window.removeEventListener("printing:selected", this.handlePrintingSelected);
  }

  handlePrintingSelected(event) {
    // Only update if this is the active/focused add-card element
    if (window.activeAddCardElement !== this.element) return;

    const {
      printingId,
      printingImage,
      printingSet,
      nonFoilAvailable,
      foilAvailable,
    } = event.detail;

    // Update the card ID value
    this.cardIdValue = parseInt(printingId);

    // Update the displayed card info
    const setEl = this.element.querySelector("p.text-xs.text-grey-text\\/70");
    const imgEl = this.element.querySelector("img[data-controller='card-hover']");

    if (setEl) {
      setEl.innerHTML = `${printingSet} <span class="text-accent-50/70">- Selected</span>`;
    }
    if (imgEl && printingImage) {
      imgEl.src = printingImage;
    }

    // Update the card type dropdown options (desktop)
    if (this.hasCardTypeSelectTarget) {
      const select = this.cardTypeSelectTarget;
      const currentValue = select.value;
      select.innerHTML = "";

      if (nonFoilAvailable) {
        const option = document.createElement("option");
        option.value = "regular";
        option.textContent = "Regular";
        select.appendChild(option);
      }
      if (foilAvailable) {
        const option = document.createElement("option");
        option.value = "foil";
        option.textContent = "Foil";
        select.appendChild(option);
      }
      // Proxy options are always available
      const proxyOption = document.createElement("option");
      proxyOption.value = "proxy";
      proxyOption.textContent = "Proxy";
      select.appendChild(proxyOption);

      const foilProxyOption = document.createElement("option");
      foilProxyOption.value = "foil_proxy";
      foilProxyOption.textContent = "Foil Proxy";
      select.appendChild(foilProxyOption);

      // Try to restore previous selection, or select first available
      if ([...select.options].some((opt) => opt.value === currentValue)) {
        select.value = currentValue;
      }
    }

    // Update mobile buttons visibility
    this.updateMobileButtons(nonFoilAvailable, foilAvailable);

    // Clear the active element
    window.activeAddCardElement = null;
  }

  updateMobileButtons(nonFoilAvailable, foilAvailable) {
    // Find and update mobile button visibility
    const regularBtn = this.element.querySelector(
      'button[data-card-type="regular"]'
    );
    const foilBtn = this.element.querySelector('button[data-card-type="foil"]');

    if (regularBtn) {
      regularBtn.classList.toggle("hidden", !nonFoilAvailable);
    }
    if (foilBtn) {
      foilBtn.classList.toggle("hidden", !foilAvailable);
    }
  }

  openChoosePrinting(event) {
    event.preventDefault();
    // Mark this element as the active one for printing selection
    window.activeAddCardElement = this.element;

    // Build URL dynamically using current cardIdValue (not the static href)
    const url = `/deck-builder/${this.deckIdValue}/choose_printing_modal?magic_card_id=${this.cardIdValue}`;

    // Open the choose printing modal via Turbo frame
    const frame = document.querySelector("turbo-frame#deck_modal");
    if (frame) {
      frame.src = url;
    }
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

  updateMaxQuantity() {
    if (!this.hasCardTypeSelectTarget || !this.hasQuantityInputTarget) return;

    const select = this.cardTypeSelectTarget;
    const cardType = select.value;

    // Get max quantity from data attributes on the select element
    let maxQty = 99;
    switch (cardType) {
      case "regular":
        maxQty = parseInt(select.dataset.addCardTargetRegularMax) || 99;
        break;
      case "foil":
        maxQty = parseInt(select.dataset.addCardTargetFoilMax) || 99;
        break;
      case "proxy":
        maxQty = parseInt(select.dataset.addCardTargetProxyMax) || 99;
        break;
      case "foil_proxy":
        maxQty = parseInt(select.dataset.addCardTargetProxyFoilMax) || 99;
        break;
    }

    this.quantityInputTarget.max = maxQty;
    if (parseInt(this.quantityInputTarget.value) > maxQty) {
      this.quantityInputTarget.value = maxQty;
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

    // Get card type from data value (owned partial) or dropdown (if present)
    let cardType = null;
    if (this.hasCardTypeValue && this.cardTypeValue) {
      cardType = this.cardTypeValue;
    } else if (this.hasCardTypeSelectTarget) {
      cardType = this.cardTypeSelectTarget.value;
    }

    await this.submitAdd(sourceId, cardType);
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

    await this.submitNewCard(cardType);
  }

  async addNewWithType(event) {
    event.preventDefault();

    const cardType = event.currentTarget.dataset.cardType || "regular";
    await this.submitNewCard(cardType);
  }

  async submitNewCard(cardType) {
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

  async submitAdd(sourceCollectionId, cardType = null) {
    const quantity = parseInt(this.quantityInputTarget.value) || 0;

    if (quantity === 0) {
      this.showAlert("Quantity Required", "Please enter a quantity");
      return;
    }

    const formData = new FormData();
    formData.append("magic_card_id", this.cardIdValue);
    formData.append("quantity", quantity);
    if (cardType) {
      formData.append("card_type", cardType);
    }
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
