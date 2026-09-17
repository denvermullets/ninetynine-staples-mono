import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="visibility-toggle"
// Shared by every public/private switch on the settings page; label names the thing in the toast.
export default class extends Controller {
  static targets = ["toggle"];
  static values = { url: String, label: String };

  async toggle(event) {
    const isPublic = event.target.checked;

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ public: isPublic }),
      });

      if (!response.ok) {
        throw new Error("Failed to save preference");
      }

      this.showToast(
        `${this.labelValue} is now ${isPublic ? "public" : "private"}`,
        "success"
      );
    } catch (error) {
      console.error(`Error saving ${this.labelValue} visibility:`, error);
      event.target.checked = !isPublic; // Revert the checkbox
      this.showToast("Failed to save preference", "error");
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
