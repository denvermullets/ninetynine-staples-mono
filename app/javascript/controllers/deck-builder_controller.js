import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="deck-builder"
export default class extends Controller {
  static targets = [
    "viewModeList",
    "viewModeCard",
    "groupingSelect",
    "cardPreview"
  ];

  static values = {
    deckId: Number,
    viewMode: { type: String, default: "list" },
    grouping: { type: String, default: "type" }
  };

  connect() {
    this.updateViewModeButtons();
    this.syncGroupingFromSelect();
  }

  syncGroupingFromSelect() {
    if (this.hasGroupingSelectTarget) {
      this.groupingValue = this.groupingSelectTarget.value;
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

  previewCard(event) {
    if (!this.hasCardPreviewTarget) return;

    const imageUrl = event.currentTarget.dataset.cardImage;
    if (imageUrl) {
      this.cardPreviewTarget.src = imageUrl;
      this.cardPreviewTarget.classList.remove("hidden");
    }
  }

  async refreshDeckDisplay() {
    const url = new URL(window.location.href);
    url.searchParams.set("view_mode", this.viewModeValue);
    url.searchParams.set("grouping", this.groupingValue);

    try {
      const response = await fetch(url, {
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
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
