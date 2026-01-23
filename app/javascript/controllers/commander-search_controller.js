import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="commander-search"
export default class extends Controller {
  static targets = [
    "input",
    "inputContainer",
    "results",
    "hiddenField",
    "selectedDisplay",
    "selectedName",
    "selectedImage",
  ];
  static values = {
    url: { type: String, default: "/game-tracker/decks/search_commanders" },
    minChars: { type: Number, default: 2 },
  };

  connect() {
    this.debounceTimer = null;
  }

  search() {
    clearTimeout(this.debounceTimer);

    const query = this.inputTarget.value.trim();
    if (query.length < this.minCharsValue) {
      this.hideResults();
      return;
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch(query);
    }, 300);
  }

  async performSearch(query) {
    try {
      const response = await fetch(
        `${this.urlValue}?q=${encodeURIComponent(query)}`,
        { headers: { Accept: "text/html" } }
      );

      const html = await response.text();
      this.resultsTarget.innerHTML = html;
      this.showResults();
    } catch (error) {
      console.error("Commander search failed:", error);
      this.resultsTarget.innerHTML =
        '<p class="text-red-400 text-sm p-2">Search failed</p>';
    }
  }

  select(event) {
    const commanderId = event.currentTarget.dataset.commanderId;
    const commanderName = event.currentTarget.dataset.commanderName;
    const commanderImage = event.currentTarget.dataset.commanderImage;
    const commanderImageLarge = event.currentTarget.dataset.commanderImageLarge;

    this.hiddenFieldTarget.value = commanderId;
    this.selectedNameTarget.textContent = commanderName;

    if (this.hasSelectedImageTarget && commanderImage) {
      this.selectedImageTarget.src = commanderImage;
      this.selectedImageTarget.alt = commanderName;
      // Update card-hover controller values for the image
      this.selectedImageTarget.dataset.cardHoverImageValue =
        commanderImageLarge || commanderImage;
      this.selectedImageTarget.dataset.cardHoverNameValue = commanderName;
    }

    this.inputTarget.value = "";
    this.hideResults();
    this.showSelected();
    this.hideInputContainer();
  }

  clear() {
    this.hiddenFieldTarget.value = "";
    this.selectedNameTarget.textContent = "";

    if (this.hasSelectedImageTarget) {
      this.selectedImageTarget.src = "";
    }

    this.hideSelected();
    this.showInputContainer();
    this.inputTarget.focus();
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden");
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden");
  }

  showSelected() {
    if (this.hasSelectedDisplayTarget) {
      this.selectedDisplayTarget.classList.remove("hidden");
    }
  }

  hideSelected() {
    if (this.hasSelectedDisplayTarget) {
      this.selectedDisplayTarget.classList.add("hidden");
    }
  }

  showInputContainer() {
    if (this.hasInputContainerTarget) {
      this.inputContainerTarget.classList.remove("hidden");
    }
  }

  hideInputContainer() {
    if (this.hasInputContainerTarget) {
      this.inputContainerTarget.classList.add("hidden");
    }
  }

  // Handle click outside to close results
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults();
    }
  }
}
