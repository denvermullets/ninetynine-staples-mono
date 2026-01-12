import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="deck-search"
export default class extends Controller {
  static targets = ["input", "results", "loading", "scopeAll", "scopeOwned"];

  static values = {
    deckId: Number,
    scope: { type: String, default: "all" },
    debounceMs: { type: Number, default: 300 }
  };

  connect() {
    this.debounceTimer = null;
    this.updateScopeButtons();
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }
  }

  search() {
    const query = this.inputTarget.value.trim();

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    if (query.length < 2) {
      this.resultsTarget.innerHTML = "";
      return;
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch(query);
    }, this.debounceValue);
  }

  async performSearch(query) {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden");
    }

    try {
      const response = await fetch(
        `/deck-builder/${this.deckIdValue}/search?q=${encodeURIComponent(query)}&scope=${this.scopeValue}`,
        {
          headers: { Accept: "text/html" }
        }
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

    // Re-search if there's a query
    const query = this.inputTarget.value.trim();
    if (query.length >= 2) {
      this.performSearch(query);
    }
  }

  updateScopeButtons() {
    if (this.hasScopeAllTarget && this.hasScopeOwnedTarget) {
      const allActive = this.scopeValue === "all";

      this.scopeAllTarget.classList.toggle("bg-accent-50", allActive);
      this.scopeAllTarget.classList.toggle("text-background", allActive);
      this.scopeAllTarget.classList.toggle("border-accent-50", allActive);

      this.scopeOwnedTarget.classList.toggle("bg-accent-50", !allActive);
      this.scopeOwnedTarget.classList.toggle("text-background", !allActive);
      this.scopeOwnedTarget.classList.toggle("border-accent-50", !allActive);
    }
  }

  clear() {
    this.inputTarget.value = "";
    this.resultsTarget.innerHTML = "";
  }
}
