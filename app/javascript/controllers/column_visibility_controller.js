import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="column-visibility"
export default class extends Controller {
  static targets = ["toggle", "error"];
  static values = { url: String, minVisible: { type: Number, default: 1 }, view: String };

  async toggle(event) {
    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]');
    const checkedCount = Array.from(checkboxes).filter((cb) => cb.checked).length;

    if (checkedCount < this.minVisibleValue) {
      event.target.checked = true;
      this.showError();
      return;
    }

    this.hideError();
    await this.savePreferences();
  }

  async savePreferences() {
    const toggles = this.toggleTargets;
    const visibleColumns = {};

    toggles.forEach((toggle) => {
      const key = toggle.dataset.columnKey;
      const checkbox = toggle.querySelector('input[type="checkbox"]');
      visibleColumns[key] = checkbox.checked;
    });

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ visible_columns: visibleColumns, view: this.viewValue }),
      });

      if (!response.ok) {
        const data = await response.json();
        if (data.error) {
          this.showError(data.error);
        }
        throw new Error("Failed to save preferences");
      }

      this.showToast("Column preferences saved", "success");
    } catch (error) {
      console.error("Error saving column visibility:", error);
      this.showToast("Failed to save preferences", "error");
    }
  }

  showError(message = "At least one column must remain visible.") {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message;
      this.errorTarget.classList.remove("hidden");
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add("hidden");
    }
  }

  showToast(message, type) {
    const toastContainer = document.getElementById("toasts");
    if (!toastContainer) return;

    const toast = document.createElement("div");
    toast.className = `px-4 py-2 rounded-lg shadow-lg ${
      type === "success" ? "bg-accent-50 text-background" : "bg-red-500 text-white"
    }`;
    toast.setAttribute("data-controller", "toast");
    toast.textContent = message;
    toastContainer.appendChild(toast);
  }
}
