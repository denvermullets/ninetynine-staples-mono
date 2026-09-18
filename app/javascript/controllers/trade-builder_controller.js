import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="trade-builder"
//
// Holds the draft trade. Nothing is written until the form is submitted, so the draft is whatever
// the quantity inputs currently say: every read of it walks the rows rather than keeping a parallel
// copy that could drift from what is on screen.
//
// Totals come from the server (Trades::DraftTotals) rather than being added up here - the prices
// live in the database and the same arithmetic appears on the saved trade, so doing it twice in two
// languages would be two places for it to disagree.
export default class extends Controller {
  static targets = ["row", "payload", "submit"];
  static values = { previewPath: String, with: String };

  connect() {
    this.toggleSubmit();
    // a preselected card arrives with a quantity already in it, so the totals start out of date
    if (this.draft().length > 0) this.refresh();
  }

  disconnect() {
    clearTimeout(this.timeout);
  }

  // every quantity input routes through here: clamp to what is available, then re-total
  change(event) {
    const input = event.currentTarget;
    const max = parseInt(input.max, 10);
    const value = Math.min(Math.max(parseInt(input.value, 10) || 0, 0), isNaN(max) ? 0 : max);
    input.value = value === 0 ? "" : value;

    this.toggleSubmit();
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => this.refresh(), 250);
  }

  clear() {
    this.rowTargets.forEach((row) => {
      this.fieldsFor(row).forEach((input) => {
        input.value = "";
      });
    });

    this.toggleSubmit();
    this.refresh();
  }

  // client-side because the rows are already all on the page - a round trip would only re-send them
  filter(event) {
    const side = event.currentTarget.dataset.side;
    const query = event.currentTarget.value.trim().toLowerCase();

    this.rowTargets
      .filter((row) => row.dataset.side === side)
      .forEach((row) => {
        const hit = query === "" || row.dataset.cardName.includes(query);
        row.classList.toggle("hidden", !hit);
      });
  }

  // the draft only becomes form fields at the last possible moment, so nothing stray is ever posted
  submit() {
    this.payloadTarget.innerHTML = "";

    this.draft().forEach((item, index) => {
      Object.entries(item).forEach(([field, value]) => {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = `items[${index}][${field}]`;
        input.value = value;
        this.payloadTarget.appendChild(input);
      });
    });
  }

  async refresh() {
    try {
      const response = await fetch(this.previewPathValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          Accept: "text/vnd.turbo-stream.html",
        },
        body: JSON.stringify({ with: this.withValue, items: this.draft() }),
      });

      if (!response.ok) return;

      Turbo.renderStreamMessage(await response.text());
    } catch (error) {
      console.error("Failed to total the trade:", error);
    }
  }

  draft() {
    return this.rowTargets
      .map((row) => {
        const quantity = this.fieldValue(row, "quantity");
        const foil_quantity = this.fieldValue(row, "foil_quantity");
        if (quantity + foil_quantity === 0) return null;

        return {
          collection_magic_card_id: row.dataset.rowId,
          side: row.dataset.side,
          quantity,
          foil_quantity,
        };
      })
      .filter(Boolean);
  }

  fieldsFor(row) {
    return Array.from(row.querySelectorAll("input[data-trade-field]"));
  }

  fieldValue(row, field) {
    const input = row.querySelector(`input[data-trade-field="${field}"]`);

    return input ? parseInt(input.value, 10) || 0 : 0;
  }

  // a trade needs at least one card on one side; which side is Trades::Propose's business
  toggleSubmit() {
    if (!this.hasSubmitTarget) return;

    this.submitTarget.disabled = this.draft().length === 0;
  }
}
