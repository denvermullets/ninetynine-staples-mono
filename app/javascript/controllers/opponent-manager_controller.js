import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="opponent-manager"
export default class extends Controller {
  static targets = ["container", "template", "addButton"];
  static values = {
    maxOpponents: { type: Number, default: 7 },
    searchUrl: { type: String, default: "/games/search_opponents" },
  };

  connect() {
    this.updateAddButtonState();
  }

  add() {
    const currentCount = this.getOpponentCount();
    if (currentCount >= this.maxOpponentsValue) return;

    const template = this.templateTarget.content.cloneNode(true);
    const index = Date.now(); // Use timestamp for unique index

    // Replace INDEX placeholder with actual index
    template.querySelectorAll("[name*='INDEX']").forEach((el) => {
      el.name = el.name.replace(/INDEX/g, index);
    });

    template.querySelectorAll("[id*='INDEX']").forEach((el) => {
      el.id = el.id.replace(/INDEX/g, index);
    });

    template.querySelectorAll("[data-index]").forEach((el) => {
      el.dataset.index = index;
    });

    this.containerTarget.appendChild(template);
    this.updateAddButtonState();
  }

  remove(event) {
    const opponentRow = event.currentTarget.closest("[data-opponent-row]");
    if (opponentRow) {
      // Check for _destroy field for Rails nested attributes
      const destroyField = opponentRow.querySelector(
        '[name*="_destroy"]'
      );
      if (destroyField) {
        destroyField.value = "1";
        opponentRow.classList.add("hidden");
      } else {
        opponentRow.remove();
      }
      this.updateAddButtonState();
    }
  }

  getOpponentCount() {
    return this.containerTarget.querySelectorAll(
      '[data-opponent-row]:not(.hidden)'
    ).length;
  }

  updateAddButtonState() {
    if (!this.hasAddButtonTarget) return;

    const canAdd = this.getOpponentCount() < this.maxOpponentsValue;
    this.addButtonTarget.disabled = !canAdd;
    this.addButtonTarget.classList.toggle("opacity-50", !canAdd);
    this.addButtonTarget.classList.toggle("cursor-not-allowed", !canAdd);
  }

  // Search for opponent commander
  async searchOpponent(event) {
    const input = event.currentTarget;
    const query = input.value.trim();
    const index = input.dataset.index;
    const resultsContainer = this.element.querySelector(
      `[data-opponent-results="${index}"]`
    );

    if (query.length < 2) {
      if (resultsContainer) resultsContainer.innerHTML = "";
      return;
    }

    try {
      const response = await fetch(
        `${this.searchUrlValue}?q=${encodeURIComponent(query)}&index=${index}`,
        { headers: { Accept: "text/html" } }
      );

      const html = await response.text();
      if (resultsContainer) {
        resultsContainer.innerHTML = html;
        resultsContainer.classList.remove("hidden");
      }
    } catch (error) {
      console.error("Opponent search failed:", error);
    }
  }

  selectOpponent(event) {
    const commanderId = event.currentTarget.dataset.commanderId;
    const commanderName = event.currentTarget.dataset.commanderName;
    const index = event.currentTarget.dataset.index;

    const hiddenField = this.element.querySelector(
      `[name*="[${index}][commander_id]"]`
    );
    const displayName = this.element.querySelector(
      `[data-opponent-name="${index}"]`
    );
    const searchInput = this.element.querySelector(
      `[data-opponent-search="${index}"]`
    );
    const resultsContainer = this.element.querySelector(
      `[data-opponent-results="${index}"]`
    );

    if (hiddenField) hiddenField.value = commanderId;
    if (displayName) displayName.textContent = commanderName;
    if (searchInput) searchInput.value = "";
    if (resultsContainer) {
      resultsContainer.innerHTML = "";
      resultsContainer.classList.add("hidden");
    }
  }
}
