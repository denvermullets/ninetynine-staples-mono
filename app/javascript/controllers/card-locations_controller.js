import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="card-locations"
export default class extends Controller {
  static targets = [
    "transferModal",
    "adjustModal",
    "fromCollectionId",
    "fromCollectionName",
    "toCollectionId",
    "toCollectionSelect",
    "transferRegularQty",
    "transferFoilQty",
    "transferRegularAvailable",
    "transferFoilAvailable",
    "adjustModal",
    "adjustCollectionId",
    "adjustCollectionName",
    "adjustRegularCurrent",
    "adjustFoilCurrent",
    "adjustRegularNew",
    "adjustFoilNew",
    "newCollectionSelect",
  ];

  // Transfer Modal Methods
  openTransferModal(event) {
    const button = event.currentTarget;
    const fromCollectionId = button.dataset.collectionId;
    const fromCollectionName = button.dataset.collectionName;
    const regularQty = parseInt(button.dataset.regularQty) || 0;
    const foilQty = parseInt(button.dataset.foilQty) || 0;

    // Set the from collection
    this.fromCollectionIdTarget.value = fromCollectionId;
    this.fromCollectionNameTarget.value = fromCollectionName;

    // Store available quantities for validation
    this.maxRegular = regularQty;
    this.maxFoil = foilQty;

    // Update available text (only if targets exist)
    if (this.hasTransferRegularAvailableTarget) {
      this.transferRegularAvailableTarget.textContent = `(available: ${regularQty})`;
    }
    if (this.hasTransferFoilAvailableTarget) {
      this.transferFoilAvailableTarget.textContent = `(available: ${foilQty})`;
    }

    // Reset transfer quantities (only if targets exist)
    if (this.hasTransferRegularQtyTarget) {
      this.transferRegularQtyTarget.value = 0;
    }
    if (this.hasTransferFoilQtyTarget) {
      this.transferFoilQtyTarget.value = 0;
    }

    // Reset to collection selection
    this.toCollectionSelectTarget.value = "";
    this.toCollectionIdTarget.value = "";

    // Filter out the source collection from the dropdown
    const options = this.toCollectionSelectTarget.options;
    for (let i = 0; i < options.length; i++) {
      if (options[i].value === fromCollectionId) {
        options[i].disabled = true;
        options[i].hidden = true;
      } else {
        options[i].disabled = false;
        options[i].hidden = false;
      }
    }

    this.transferModalTarget.classList.remove("hidden");
  }

  closeTransferModal() {
    this.transferModalTarget.classList.add("hidden");
  }

  updateToCollection(event) {
    this.toCollectionIdTarget.value = event.target.value;
  }

  incrementTransferRegular() {
    const current = parseInt(this.transferRegularQtyTarget.value) || 0;
    if (current < this.maxRegular) {
      this.transferRegularQtyTarget.value = current + 1;
    }
  }

  decrementTransferRegular() {
    const current = parseInt(this.transferRegularQtyTarget.value) || 0;
    if (current > 0) {
      this.transferRegularQtyTarget.value = current - 1;
    }
  }

  incrementTransferFoil() {
    const current = parseInt(this.transferFoilQtyTarget.value) || 0;
    if (current < this.maxFoil) {
      this.transferFoilQtyTarget.value = current + 1;
    }
  }

  decrementTransferFoil() {
    const current = parseInt(this.transferFoilQtyTarget.value) || 0;
    if (current > 0) {
      this.transferFoilQtyTarget.value = current - 1;
    }
  }

  // Adjust Modal Methods
  openAdjustModal(event) {
    const button = event.currentTarget;
    const isNewCollection = button.dataset.isNew === "true";

    let collectionId, collectionName, regularQty, foilQty;

    if (isNewCollection) {
      // Get the selected collection from the dropdown
      const selectedOption = this.newCollectionSelectTarget.selectedOptions[0];
      if (!selectedOption || !selectedOption.value) {
        alert("Please select a collection first");
        return;
      }
      collectionId = selectedOption.value;
      collectionName = selectedOption.text;
      regularQty = 0;
      foilQty = 0;
    } else {
      collectionId = button.dataset.collectionId;
      collectionName = button.dataset.collectionName;
      regularQty = parseInt(button.dataset.regularQty) || 0;
      foilQty = parseInt(button.dataset.foilQty) || 0;
    }

    // Set the collection info
    this.adjustCollectionIdTarget.value = collectionId;
    this.adjustCollectionNameTarget.textContent = `(${collectionName})`;

    // Set current quantities
    this.adjustRegularCurrentTarget.textContent = regularQty;
    this.adjustFoilCurrentTarget.textContent = foilQty;

    // Set new quantities (defaults to current)
    this.adjustRegularNewTarget.value = regularQty;
    this.adjustFoilNewTarget.value = foilQty;

    this.adjustModalTarget.classList.remove("hidden");
  }

  closeAdjustModal() {
    this.adjustModalTarget.classList.add("hidden");
  }

  // Utility method to prevent modal close when clicking inside
  stopPropagation(event) {
    event.stopPropagation();
  }
}
