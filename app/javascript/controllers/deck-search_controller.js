import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="deck-search"
export default class extends Controller {
  static targets = ["form", "input", "results", "loading", "scopeAll", "scopeOwned", "scopeField"];

  static values = {
    deckId: Number,
    scope: { type: String, default: "all" },
  };

  connect() {
    this.updateScopeButtons();
    this.boundClear = this.clear.bind(this);
    window.addEventListener("deck:card-added", this.boundClear);
  }

  disconnect() {
    window.removeEventListener("deck:card-added", this.boundClear);
  }

  async submit(event) {
    event.preventDefault();

    const query = this.inputTarget.value.trim();
    if (query.length < 2) {
      this.resultsTarget.innerHTML = "";
      return;
    }

    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden");
    }

    try {
      const response = await fetch(
        `/deck-builder/${this.deckIdValue}/search?q=${encodeURIComponent(query)}&scope=${this.scopeValue}`,
        { headers: { Accept: "text/html" } }
      );

      const html = await response.text();
      this.resultsTarget.innerHTML = html;
    } catch (error) {
      console.error("Search failed:", error);
      this.resultsTarget.innerHTML = '<p class="text-red-400 text-sm">Search failed</p>';
    } finally {
      if (this.hasLoadingTarget) {
        this.loadingTarget.classList.add("hidden");
      }
    }
  }

  setScope(event) {
    this.scopeValue = event.currentTarget.dataset.scope;
    this.updateScopeButtons();

    if (this.hasScopeFieldTarget) {
      this.scopeFieldTarget.value = this.scopeValue;
    }

    // Re-search if there's a query
    const query = this.inputTarget.value.trim();
    if (query.length >= 2) {
      this.formTarget.requestSubmit();
    }
  }

  updateScopeButtons() {
    if (this.hasScopeAllTarget && this.hasScopeOwnedTarget) {
      const allActive = this.scopeValue === "all";

      this.scopeAllTarget.classList.toggle("bg-accent-50", allActive);
      this.scopeAllTarget.classList.toggle("text-background", allActive);
      this.scopeAllTarget.classList.toggle("border-accent-50", allActive);
      this.scopeAllTarget.classList.toggle("text-grey-text", !allActive);

      this.scopeOwnedTarget.classList.toggle("bg-accent-50", !allActive);
      this.scopeOwnedTarget.classList.toggle("text-background", !allActive);
      this.scopeOwnedTarget.classList.toggle("border-accent-50", !allActive);
      this.scopeOwnedTarget.classList.toggle("text-grey-text", allActive);
    }
  }

  clear() {
    this.inputTarget.value = "";
    this.resultsTarget.innerHTML = "";
  }
}
