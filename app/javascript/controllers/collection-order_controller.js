import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="collection-order"
// Drag and drop reordering for the settings collection list. Lives on the turbo frame so it survives
// the list being re-rendered; the server answers with the same turbo stream the arrow buttons use.
export default class extends Controller {
  static values = { url: String };

  start(event) {
    this.dragging = event.target.closest("[data-collection-id]");
    if (!this.dragging) return;

    this.orderBefore = this.currentOrder().join(",");
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", this.dragging.dataset.collectionId);
    requestAnimationFrame(() => this.dragging?.classList.add("opacity-40"));
  }

  over(event) {
    if (!this.dragging) return;
    event.preventDefault();

    const row = event.target.closest("[data-collection-id]");
    if (!row || row === this.dragging) return;

    const { top, height } = row.getBoundingClientRect();
    const after = event.clientY > top + height / 2;
    row.parentNode.insertBefore(this.dragging, after ? row.nextSibling : row);
  }

  drop(event) {
    if (this.dragging) event.preventDefault();
  }

  end() {
    if (!this.dragging) return;

    this.dragging.classList.remove("opacity-40");
    this.dragging = null;
    if (this.currentOrder().join(",") !== this.orderBefore) this.save();
  }

  currentOrder() {
    return [...this.element.querySelectorAll("[data-collection-id]")].map(
      (row) => row.dataset.collectionId
    );
  }

  async save() {
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ collection_ids: this.currentOrder() }),
      });

      if (!response.ok) throw new Error("Failed to save collection order");

      window.Turbo.renderStreamMessage(await response.text());
    } catch (error) {
      console.error("Error saving collection order:", error);
      this.showToast("Failed to save collection order", "error");
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
