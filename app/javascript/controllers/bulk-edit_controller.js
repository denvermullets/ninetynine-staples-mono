import { Controller } from "@hotwired/stimulus";

const VARIANTS = ["quantity", "foil_quantity", "proxy_quantity", "proxy_foil_quantity"];

// Connects to data-controller="bulk-edit"
export default class extends Controller {
  static targets = ["row", "saveButton", "results"];
  static values = { savePath: String };

  async save() {
    const rows = this.collectRows();

    if (rows.length === 0) {
      this.renderMessage("Nothing to save — pick FROM, TO, and a quantity on at least one row.");
      return;
    }

    this.setSaveButtonsDisabled(true);
    try {
      const response = await fetch(this.savePathValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          Accept: "text/vnd.turbo-stream.html",
        },
        body: JSON.stringify({ rows }),
      });

      if (!response.ok) {
        this.renderMessage(`Save failed (${response.status}).`, true);
        return;
      }

      const html = await response.text();
      Turbo.renderStreamMessage(html);
    } catch (e) {
      console.error("Bulk edit save failed:", e);
      this.renderMessage("Save failed — see console for details.", true);
    } finally {
      this.setSaveButtonsDisabled(false);
    }
  }

  setSaveButtonsDisabled(disabled) {
    this.saveButtonTargets.forEach((b) => {
      b.disabled = disabled;
    });
  }

  collectRows() {
    return this.rowTargets
      .map((row) => {
        const fromSelect = row.querySelector("select[data-collection-role='from']");
        const toSelect = row.querySelector("select[data-collection-role='to']");
        const data = {
          magic_card_id: row.dataset.magicCardId,
          card_uuid: row.dataset.cardUuid || null,
          from_collection_id: fromSelect ? fromSelect.value : "",
          to_collection_id: toSelect ? toSelect.value : "",
        };
        VARIANTS.forEach((variant) => {
          const input = row.querySelector(`input[data-variant='${variant}']`);
          data[variant] = input ? parseInt(input.value, 10) || 0 : 0;
        });
        return data;
      })
      .filter(
        (row) =>
          row.from_collection_id &&
          row.to_collection_id &&
          VARIANTS.some((v) => row[v] > 0)
      );
  }

  renderMessage(message, isError = false) {
    if (!this.hasResultsTarget) return;
    const tone = isError ? "text-accent-100" : "text-grey-text/80";
    this.resultsTarget.innerHTML = `
      <div class="p-4 border rounded-xl bg-foreground border-highlight text-grey-text">
        <p class="font-semibold ${tone}">${message}</p>
      </div>
    `;
  }
}
