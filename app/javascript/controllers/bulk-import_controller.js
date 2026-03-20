import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="bulk-import"
export default class extends Controller {
  static targets = [
    "textarea",
    "progressText",
    "progressBar",
    "cardName",
    "cardQuantity",
    "resultsContainer",
    "summaryContainer",
    "pastePhase",
    "resolvePhase",
    "summaryPhase",
  ];

  static values = {
    deckId: Number,
    deckPath: String,
  };

  connect() {
    this.cards = [];
    this.currentIndex = 0;
    this.outcomes = [];
    this.handlePrintingSelected = this.printingSelected.bind(this);
    window.addEventListener("printing:selected", this.handlePrintingSelected);
  }

  disconnect() {
    window.removeEventListener(
      "printing:selected",
      this.handlePrintingSelected,
    );
  }

  startImport() {
    const text = this.textareaTarget.value.trim();
    if (!text) return;

    this.cards = this.parseCardList(text);
    if (this.cards.length === 0) return;

    this.currentIndex = 0;
    this.outcomes = [];

    this.pastePhaseTarget.classList.add("hidden");
    this.resolvePhaseTarget.classList.remove("hidden");

    this.processCurrentCard();
  }

  cancelImport() {
    this.cards = [];
    this.currentIndex = 0;
    this.outcomes = [];
    this.resultsContainerTarget.innerHTML = "";

    this.resolvePhaseTarget.classList.add("hidden");
    this.summaryPhaseTarget.classList.add("hidden");
    this.pastePhaseTarget.classList.remove("hidden");
  }

  parseCardList(text) {
    const lines = text.split("\n");
    const cards = [];

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      const match = trimmed.match(/^(\d+)x?\s+(.+)$/i);
      if (match) {
        cards.push({ qty: parseInt(match[1]), name: match[2].trim() });
      } else {
        cards.push({ qty: 1, name: trimmed });
      }
    }

    return cards;
  }

  async processCurrentCard() {
    if (this.currentIndex >= this.cards.length) {
      this.showSummary();
      return;
    }

    const card = this.cards[this.currentIndex];
    const progress = this.currentIndex + 1;
    const total = this.cards.length;

    this.progressTextTarget.textContent = `Card ${progress} of ${total}`;
    this.progressBarTarget.style.width = `${(progress / total) * 100}%`;
    this.cardNameTarget.textContent = card.name;
    this.cardQuantityTarget.textContent = card.qty;

    this.resultsContainerTarget.innerHTML = `
      <div class="flex items-center justify-center py-8">
        <svg class="animate-spin h-6 w-6 text-accent-50" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
        </svg>
      </div>
    `;

    try {
      const url = `/deck-builder/${this.deckIdValue}/bulk_import_search?name=${encodeURIComponent(card.name)}&quantity=${card.qty}`;
      const response = await fetch(url, {
        headers: {
          Accept: "text/html",
          "X-CSRF-Token": this.csrfToken,
        },
      });
      const html = await response.text();
      this.resultsContainerTarget.innerHTML = html;
    } catch (error) {
      console.error("Failed to search card:", error);
      this.resultsContainerTarget.innerHTML = `
        <p class="py-4 text-sm text-center text-grey-text">Search failed</p>
      `;
    }
  }

  printingSelected(event) {
    const { printingId, printingImage, printingImageLarge, printingSet } =
      event.detail;

    // Update all magic_card_id data attributes in the results
    this.resultsContainerTarget
      .querySelectorAll("[data-magic-card-id]")
      .forEach((btn) => {
        btn.dataset.magicCardId = printingId;
      });

    // Update displayed image (first img in results)
    const img = this.resultsContainerTarget.querySelector("img");
    if (img) {
      img.src = printingImage || img.src;
      if (printingImageLarge) {
        img.dataset.cardHoverImageValue = printingImageLarge;
      }
    }

    // Update set text
    const setEl = this.resultsContainerTarget.querySelector(
      ".text-grey-text\\/70",
    );
    if (setEl && printingSet) {
      setEl.textContent = printingSet;
    }
  }

  async addOwned(event) {
    event.preventDefault();
    const btn = event.currentTarget;
    const formData = new FormData();
    formData.append("magic_card_id", btn.dataset.magicCardId);
    formData.append("source_collection_id", btn.dataset.sourceCollectionId);
    formData.append("card_type", btn.dataset.cardType);
    formData.append("quantity", btn.dataset.quantity);

    await this.submitCard(`/deck-builder/${this.deckIdValue}/add_card`, formData);
    this.outcomes.push({
      name: this.cards[this.currentIndex].name,
      status: "added",
    });
    this.advance();
  }

  async addNew(event) {
    event.preventDefault();
    const btn = event.currentTarget;
    const formData = new FormData();
    formData.append("magic_card_id", btn.dataset.magicCardId);
    formData.append("card_type", "regular");
    formData.append("quantity", btn.dataset.quantity);

    await this.submitCard(
      `/deck-builder/${this.deckIdValue}/add_new_card`,
      formData,
    );
    this.outcomes.push({
      name: this.cards[this.currentIndex].name,
      status: "added",
    });
    this.advance();
  }

  async addPlanned(event) {
    event.preventDefault();
    const btn = event.currentTarget;
    const formData = new FormData();
    formData.append("magic_card_id", btn.dataset.magicCardId);
    formData.append("card_type", btn.dataset.cardType || "regular");
    formData.append("quantity", btn.dataset.quantity);

    await this.submitCard(`/deck-builder/${this.deckIdValue}/add_card`, formData);
    this.outcomes.push({
      name: this.cards[this.currentIndex].name,
      status: "planned",
    });
    this.advance();
  }

  skip() {
    this.outcomes.push({
      name: this.cards[this.currentIndex].name,
      status: "skipped",
    });
    this.advance();
  }

  advance() {
    this.currentIndex++;
    this.processCurrentCard();
  }

  showSummary() {
    this.resolvePhaseTarget.classList.add("hidden");
    this.summaryPhaseTarget.classList.remove("hidden");

    const added = this.outcomes.filter((o) => o.status === "added").length;
    const planned = this.outcomes.filter((o) => o.status === "planned").length;
    const skipped = this.outcomes.filter((o) => o.status === "skipped").length;

    let html = `
      <div class="mb-4 space-y-1">
        <p class="text-sm text-nine-white font-medium">Import Complete</p>
        <p class="text-xs text-grey-text">${added} added, ${planned} planned, ${skipped} skipped</p>
      </div>
      <div class="max-h-96 overflow-y-auto space-y-1">
    `;

    for (const outcome of this.outcomes) {
      let badge = "";
      if (outcome.status === "added") {
        badge = `<span class="px-2 py-0.5 text-xs rounded bg-accent-50/20 text-accent-50">Added</span>`;
      } else if (outcome.status === "planned") {
        badge = `<span class="px-2 py-0.5 text-xs rounded bg-accent-400/20 text-accent-400">Planned</span>`;
      } else {
        badge = `<span class="px-2 py-0.5 text-xs rounded bg-highlight text-grey-text">Skipped</span>`;
      }

      html += `
        <div class="flex items-center justify-between py-1 px-2 rounded bg-foreground/50">
          <span class="text-sm text-grey-text truncate">${this.escapeHtml(outcome.name)}</span>
          ${badge}
        </div>
      `;
    }

    html += `</div>`;
    this.summaryContainerTarget.innerHTML = html;
  }

  async submitCard(url, formData) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken,
          Accept: "text/vnd.turbo-stream.html",
        },
        body: formData,
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);
    } catch (error) {
      console.error("Failed to add card:", error);
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content;
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
