import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="trade-builder"
//
// Holds the draft trade. Nothing is written until the form is submitted, so the draft is whatever
// the quantity inputs currently say: every read of it walks the rows rather than keeping a parallel
// copy that could drift from what is on screen.
//
// Each column lists its owner's trade list and searches the rest of their public collections
// (trades#rows) into a turbo frame. A search hit is an ordinary row, so it is in the draft as soon as
// it has a quantity - and at that moment it is moved out of the frame into the column's list, because
// the next search replaces the frame and would take the draft with it.
//
// Totals come from the server (Trades::DraftTotals) rather than being added up here - the prices
// live in the database and the same arithmetic appears on the saved trade, so doing it twice in two
// languages would be two places for it to disagree.
export default class extends Controller {
  static targets = ["row", "payload", "submit", "list", "results", "empty"];
  static values = { previewPath: String, rowsPath: String, with: String, counter: String };

  connect() {
    // one entry per column: the name box and the "matched only" toggle both narrow the same list
    this.filters = {};
    this.toggleSubmit();
    // a counter-offer can start with copies from off the trade list already in it
    this.rowTargets.forEach((row) => this.flagOffList(row));
    // a preselected card arrives with a quantity already in it, so the totals start out of date
    if (this.draft().length > 0) this.refresh();
  }

  disconnect() {
    clearTimeout(this.timeout);
    clearTimeout(this.searchTimeout);
  }

  // a row already in the column must not come back as a search hit - two inputs, one draft item
  resultsTargetConnected(frame) {
    frame.addEventListener("turbo:frame-load", () => this.dropPinned(frame));
  }

  // every quantity input routes through here: clamp to what is available, then re-total
  change(event) {
    const input = event.currentTarget;
    const max = parseInt(input.max, 10);
    const value = Math.min(Math.max(parseInt(input.value, 10) || 0, 0), isNaN(max) ? 0 : max);
    input.value = value === 0 ? "" : value;

    const row = input.closest('[data-trade-builder-target="row"]');
    this.flagOffList(row);
    if (value > 0) this.pin(row, input);

    this.toggleSubmit();
    // a row that just gained or lost copies may now belong on the other side of "matched only" -
    // only worth walking the column when that is actually what it is narrowed to
    if (this.filters[row.dataset.side]?.matchedOnly) this.applyFilters(row.dataset.side);
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => this.refresh(), 250);
  }

  clear() {
    this.rowTargets.forEach((row) => {
      this.fieldsFor(row).forEach((input) => {
        input.value = "";
      });
      this.flagOffList(row);
    });

    this.toggleSubmit();
    // every row is out of the draft now, so a column narrowed to matches has rows to hide
    Object.keys(this.filters)
      .filter((side) => this.filters[side].matchedOnly)
      .forEach((side) => this.applyFilters(side));
    this.refresh();
  }

  // client-side because the rows are already all on the page - a round trip would only re-send them
  filter(event) {
    const side = event.currentTarget.dataset.side;
    this.filterState(side).query = event.currentTarget.value.trim().toLowerCase();
    this.applyFilters(side);
  }

  // Narrows a column to the rows the want matches page sent the proposer here for. A row already
  // holding copies stays whatever the toggle says: hiding part of the draft would be lying about
  // what is on the table, and it is also what keeps a search hit visible after it has been pinned.
  matchedOnly(event) {
    const button = event.currentTarget;
    const side = button.dataset.side;
    const state = this.filterState(side);

    state.matchedOnly = !state.matchedOnly;
    button.setAttribute("aria-pressed", String(state.matchedOnly));
    this.applyFilters(side);
  }

  applyFilters(side) {
    const { query, matchedOnly } = this.filterState(side);

    this.rowTargets
      .filter((row) => row.dataset.side === side)
      .forEach((row) => {
        const byName = query === "" || row.dataset.cardName.includes(query);
        const byMatch = !matchedOnly || row.dataset.matched === "true" || this.inDraft(row);
        row.classList.toggle("hidden", !(byName && byMatch));
      });
  }

  filterState(side) {
    return (this.filters[side] ||= { query: "", matchedOnly: false });
  }

  inDraft(row) {
    return this.fieldsFor(row).some((input) => (parseInt(input.value, 10) || 0) > 0);
  }

  // the rest of this side's public collections, by name; an emptied box empties the results
  search(event) {
    const input = event.currentTarget;
    const frame = this.resultsTargets.find((target) => target.dataset.side === input.dataset.side);
    if (!frame) return;

    clearTimeout(this.searchTimeout);
    this.searchTimeout = setTimeout(() => {
      const params = new URLSearchParams({ with: this.withValue, side: input.dataset.side, q: input.value.trim() });
      if (this.counterValue) params.set("counter", this.counterValue);

      frame.src = `${this.rowsPathValue}?${params}`;
    }, 300);
  }

  // a search hit that now holds copies joins the column's list, keeping the cursor where it was
  pin(row, input) {
    if (!row.closest('[data-trade-builder-target="results"]')) return;

    const side = row.dataset.side;
    this.listTargets.find((list) => list.dataset.side === side)?.prepend(row);
    this.emptyTargets.filter((empty) => empty.dataset.side === side).forEach((empty) => empty.classList.add("hidden"));
    input.focus();
  }

  dropPinned(frame) {
    const list = this.listTargets.find((target) => target.dataset.side === frame.dataset.side);
    if (!list) return;

    frame.querySelectorAll('[data-trade-builder-target="row"]').forEach((row) => {
      if (list.querySelector(`[data-row-id="${row.dataset.rowId}"]`)) row.remove();
    });
  }

  // the badge shows while the row asks for more copies than its owner listed - always, if none are
  flagOffList(row) {
    const badge = row.querySelector("[data-off-list-badge]");
    if (!badge) return;

    const past = this.fieldsFor(row).some((input) => (parseInt(input.value, 10) || 0) > parseInt(input.dataset.listed, 10));
    badge.classList.toggle("hidden", !(row.dataset.unlisted === "true" || past));
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
