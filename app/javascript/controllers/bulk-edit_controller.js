import { Controller } from "@hotwired/stimulus";

const VARIANTS = ["quantity", "foil_quantity", "proxy_quantity", "proxy_foil_quantity"];

// Connects to data-controller="bulk-edit"
export default class extends Controller {
  static targets = ["row", "saveButton"];
  static values = { savePath: String };

  async save() {
    const submittable = this.submittableRows();

    if (submittable.length === 0) {
      this.showToast("Nothing to save — pick FROM, TO, and a quantity on at least one row.", true);
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
        body: JSON.stringify({ rows: submittable.map(({ data }) => data) }),
      });

      if (!response.ok) {
        this.showToast(`Save failed (${response.status}).`, true);
        return;
      }

      const succeeded = response.headers.get("X-Bulk-Edit-Success") === "true";
      const html = await response.text();
      Turbo.renderStreamMessage(html);

      // the collections these rows read from have moved on, so re-seed them
      if (succeeded) this.refreshRows(submittable.map(({ row }) => row));
    } catch (e) {
      console.error("Bulk edit save failed:", e);
      this.showToast("Save failed — see console for details.", true);
    } finally {
      this.setSaveButtonsDisabled(false);
    }
  }

  setSaveButtonsDisabled(disabled) {
    this.saveButtonTargets.forEach((b) => {
      b.disabled = disabled;
    });
  }

  submittableRows() {
    return this.rowTargets
      .map((row) => ({ row, data: this.readRow(row) }))
      .filter(({ row, data }) => {
        if (!data.from_collection_id || !data.to_collection_id) return false;
        if (!VARIANTS.some((v) => data[v] > 0)) return false;

        // a prefilled row left untouched would just rewrite the totals it already has
        return !this.matchesBaseline(row, data);
      });
  }

  readRow(row) {
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
  }

  matchesBaseline(row, data) {
    if (!row.dataset.baseline) return false;

    try {
      const baseline = JSON.parse(row.dataset.baseline);
      return VARIANTS.every((v) => (baseline[v] || 0) === data[v]);
    } catch {
      return false;
    }
  }

  refreshRows(rows) {
    rows.forEach((row) => {
      const rowController = this.application.getControllerForElementAndIdentifier(row, "bulk-edit-row");
      if (rowController) rowController.refresh();
    });
  }

  // mirrors shared/_toast so client-side failures look like every other toast in the app
  showToast(message, isError = false) {
    const container = document.getElementById("toasts");
    if (!container) return;

    const toast = document.createElement("div");
    toast.dataset.controller = "toast";
    toast.className = `p-4 rounded-lg shadow-lg text-menu ${isError ? "bg-accent-100" : "bg-accent-50"}`;
    toast.textContent = message;
    container.appendChild(toast);
  }
}
