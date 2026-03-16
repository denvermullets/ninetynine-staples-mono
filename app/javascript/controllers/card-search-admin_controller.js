import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="card-search-admin"
export default class extends Controller {
  static targets = ["searchInput", "results", "oracleId", "cardName"];

  connect() {
    this.timeout = null;
  }

  disconnect() {
    clearTimeout(this.timeout);
  }

  search() {
    clearTimeout(this.timeout);
    const query = this.searchInputTarget.value.trim();

    if (query.length < 2) {
      this.hideResults();
      return;
    }

    this.timeout = setTimeout(() => this.fetchResults(query), 300);
  }

  async fetchResults(query) {
    const url = `/admin/game_changers/search_cards?q=${encodeURIComponent(query)}`;

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
      });
      const cards = await response.json();
      this.renderResults(cards);
    } catch {
      this.hideResults();
    }
  }

  renderResults(cards) {
    if (cards.length === 0) {
      this.hideResults();
      return;
    }

    this.resultsTarget.innerHTML = cards
      .map(
        (card) =>
          `<button type="button"
            class="w-full text-left px-3 py-2 text-sm text-grey-text hover:bg-foreground hover:text-white transition cursor-pointer"
            data-action="click->card-search-admin#selectCard"
            data-oracle-id="${card.oracle_id}"
            data-card-name="${this.escapeHtml(card.name)}">
            ${this.escapeHtml(card.name)}
          </button>`
      )
      .join("");

    this.resultsTarget.classList.remove("hidden");
  }

  selectCard(event) {
    event.preventDefault();
    const { oracleId, cardName } = event.currentTarget.dataset;

    this.oracleIdTarget.value = oracleId;
    this.cardNameTarget.value = cardName;
    this.searchInputTarget.value = cardName;
    this.hideResults();
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden");
    this.resultsTarget.innerHTML = "";
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
