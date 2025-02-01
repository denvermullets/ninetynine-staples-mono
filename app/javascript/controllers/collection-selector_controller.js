import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="collection-selector"
export default class extends Controller {
  static targets = ["quantity", "foilQuantity"];

  connect() {
    const cardRow = this.element.closest("tr[data-card-id]");

    if (cardRow) {
      const collectionDropdown = cardRow.querySelector("[name='collection_id']");
      const collectionId = collectionDropdown.value;
      const cardId = cardRow.getAttribute("data-card-id");

      this.queryCollection(collectionId, cardId);
    }
  }

  queryCollection(collection, magicCard) {
    fetch(`/collection_magic_cards/quantity?collection_id=${collection}&magic_card_id=${magicCard}`)
      .then((response) => response.json())
      .then((data) => {
        this.quantityTarget.value = data.quantity;
        this.foilQuantityTarget.value = data.foil_quantity;
      })
      .catch((error) => console.error("Error fetching data:", error));
  }

  fetchCollection(event) {
    const collection = event.target.value;
    const magicCard = this.findCardId(event);

    if (!collection) {
      this.quantityTarget.value = 0;
      this.foilQuantityTarget.value = 0;
      return;
    }

    this.queryCollection(collection, magicCard);
  }

  findCardId(event) {
    // probably could do some better error handling but it should alawys find it
    const cardRow = event.target.closest("tr[data-card-id]");
    if (cardRow) {
      const cardId = cardRow.getAttribute("data-card-id");

      return cardId;
    }
  }
}
