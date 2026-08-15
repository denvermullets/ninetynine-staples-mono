import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="deck-search"
export default class extends Controller {
  static targets = [
    "form",
    "input",
    "results",
    "loading",
    "scopeAll",
    "scopeOwned",
    "scopeSuggestions",
    "scopeField",
    "searchPane",
    "suggestionsPane",
  ];

  static values = {
    deckId: Number,
    scope: { type: String, default: "all" },
  };

  // Scope name -> the target holding its button. Adding a fourth scope means one entry here, not
  // another branch in updateScopeButtons.
  get scopeButtons() {
    return {
      all: this.hasScopeAllTarget ? this.scopeAllTarget : null,
      owned: this.hasScopeOwnedTarget ? this.scopeOwnedTarget : null,
      suggestions: this.hasScopeSuggestionsTarget ? this.scopeSuggestionsTarget : null,
    };
  }

  connect() {
    this.updateScopeButtons();
    this.updatePanes();
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
    this.updatePanes();

    if (this.hasScopeFieldTarget) {
      this.scopeFieldTarget.value = this.scopeValue;
    }

    if (this.showingSuggestions) return;

    // Re-search if there's a query
    const query = this.inputTarget.value.trim();
    if (query.length >= 2) {
      this.formTarget.requestSubmit();
    }
  }

  get showingSuggestions() {
    return this.scopeValue === "suggestions";
  }

  updateScopeButtons() {
    Object.entries(this.scopeButtons).forEach(([scope, button]) => {
      if (!button) return;

      const active = this.scopeValue === scope;
      button.classList.toggle("bg-accent-50", active);
      button.classList.toggle("text-background", active);
      button.classList.toggle("border-accent-50", active);
      button.classList.toggle("text-grey-text", !active);
    });
  }

  // Suggestions is a whole different question from search, so the two swap places rather than sharing
  // the results container.
  updatePanes() {
    if (this.hasSearchPaneTarget) {
      this.searchPaneTarget.classList.toggle("hidden", this.showingSuggestions);
    }
    if (this.hasSuggestionsPaneTarget) {
      this.suggestionsPaneTarget.classList.toggle("hidden", !this.showingSuggestions);
    }
  }

  // Fired after every add. Search results are wiped, but the suggestion list is exactly what you want
  // to keep looking at while filling a bucket - so it reloads instead, dropping the card just added.
  clear() {
    this.inputTarget.value = "";
    this.resultsTarget.innerHTML = "";

    const frame = this.element.querySelector("turbo-frame#deck_suggestions");
    if (frame && frame.src) frame.reload();
  }
}
