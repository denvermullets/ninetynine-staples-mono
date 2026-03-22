import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="collection-link"
export default class extends Controller {
  static targets = ["wrapper", "container"];
  static values = {
    url: { type: String, default: "/game-tracker/decks/matching_collections" },
    selectedId: { type: Number, default: 0 },
  };

  connect() {
    this.element.addEventListener(
      "commander:changed",
      this.handleCommanderChanged.bind(this)
    );

    // If commander is already set (edit form), fetch matching collections
    const commanderField = this.element.querySelector(
      "#tracked_deck_commander_id"
    );
    if (commanderField?.value) {
      this.fetchCollections(commanderField.value);
    }
  }

  disconnect() {
    this.element.removeEventListener(
      "commander:changed",
      this.handleCommanderChanged.bind(this)
    );
  }

  handleCommanderChanged(event) {
    const commanderId = event.detail?.id;

    if (commanderId) {
      this.fetchCollections(commanderId);
    } else {
      this.hide();
    }
  }

  async fetchCollections(commanderId) {
    try {
      const url = new URL(this.urlValue, window.location.origin);
      url.searchParams.set("commander_id", commanderId);

      // Pass currently selected collection_id for pre-selection
      const currentSelect = this.containerTarget.querySelector("select");
      const selectedId = currentSelect?.value || this.selectedIdValue;
      if (selectedId) {
        url.searchParams.set("selected_id", selectedId);
      }

      const response = await fetch(url, { headers: { Accept: "text/html" } });
      const html = await response.text();
      this.containerTarget.innerHTML = html;
      this.show();
    } catch (error) {
      console.error("Failed to fetch matching collections:", error);
    }
  }

  show() {
    this.wrapperTarget.classList.remove("hidden");
  }

  hide() {
    this.wrapperTarget.classList.add("hidden");
    this.containerTarget.innerHTML = "";
  }
}
