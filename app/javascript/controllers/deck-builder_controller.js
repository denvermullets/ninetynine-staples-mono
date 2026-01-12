import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="deck-builder"
export default class extends Controller {
  static targets = ["viewModeList", "viewModeCard", "groupingSelect", "sortBySelect", "cardPreview", "cardPreviewName"];

  static values = {
    deckId: Number,
    viewMode: { type: String, default: "list" },
    grouping: { type: String, default: "type" },
    sortBy: { type: String, default: "mana_value" },
  };

  connect() {
    this.updateViewModeButtons();
    this.syncSelectsFromValues();
  }

  syncSelectsFromValues() {
    if (this.hasGroupingSelectTarget) {
      this.groupingValue = this.groupingSelectTarget.value;
    }
    if (this.hasSortBySelectTarget) {
      this.sortByValue = this.sortBySelectTarget.value;
    }
  }

  setViewMode(event) {
    const mode = event.currentTarget.dataset.mode;
    this.viewModeValue = mode;
    this.updateViewModeButtons();
    this.refreshDeckDisplay();
  }

  updateViewModeButtons() {
    if (this.hasViewModeListTarget && this.hasViewModeCardTarget) {
      const listActive = this.viewModeValue === "list";
      const cardActive = this.viewModeValue === "card";

      this.viewModeListTarget.classList.toggle("bg-accent-50", listActive);
      this.viewModeListTarget.classList.toggle("text-background", listActive);
      this.viewModeListTarget.classList.toggle("border-accent-50", listActive);

      this.viewModeCardTarget.classList.toggle("bg-accent-50", cardActive);
      this.viewModeCardTarget.classList.toggle("text-background", cardActive);
      this.viewModeCardTarget.classList.toggle("border-accent-50", cardActive);
    }
  }

  changeGrouping(event) {
    this.groupingValue = event.target.value;
    this.refreshDeckDisplay();
  }

  changeSortBy(event) {
    this.sortByValue = event.target.value;
    this.refreshDeckDisplay();
  }

  previewCard(event) {
    const imageUrl = event.currentTarget.dataset.cardImage;
    const cardName = event.currentTarget.dataset.cardName;

    if (this.hasCardPreviewTarget && imageUrl) {
      this.cardPreviewTarget.src = imageUrl;
      this.cardPreviewTarget.classList.remove("hidden");
    }

    if (this.hasCardPreviewNameTarget && cardName) {
      this.cardPreviewNameTarget.textContent = cardName;
    }
  }

  async refreshDeckDisplay() {
    const url = new URL(window.location.href);
    url.searchParams.set("view_mode", this.viewModeValue);
    url.searchParams.set("grouping", this.groupingValue);
    url.searchParams.set("sort_by", this.sortByValue);

    try {
      const response = await fetch(url, {
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest",
        },
      });

      if (!response.ok) {
        console.error("Deck refresh failed:", response.status);
        return;
      }

      const html = await response.text();
      Turbo.renderStreamMessage(html);
      history.replaceState(null, "", url);
    } catch (error) {
      console.error("Deck refresh error:", error);
    }
  }
}
